import os
import uuid
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / '.env')
import cv2
import joblib
import numpy as np
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from PIL import Image, ImageDraw, ImageFont
from ultralytics import YOLO
import cloudinary
import cloudinary.uploader

# ========== Cloudinary Setup (set in backend/.env — do not commit secrets) ==========
cloudinary.config(
    cloud_name=os.environ.get('CLOUDINARY_CLOUD_NAME', ''),
    api_key=os.environ.get('CLOUDINARY_API_KEY', ''),
    api_secret=os.environ.get('CLOUDINARY_API_SECRET', ''),
)

# ========== App Setup ==========
app = Flask(__name__)
CORS(app)
UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# ========== Load Models ==========
yolo_model = YOLO("best.pt")
xgb_model = joblib.load("final_score_model_xgboost.pkl")  # XGBoost model trained with only scores

# ========== Serve Uploaded Images ==========
@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# ========== Weld Detection Endpoint ==========
@app.route('/api/predict', methods=['POST'])
def predict_defect():
    file = request.files.get('file')
    if not file:
        return jsonify({'error': 'No file uploaded'}), 400

    # Save uploaded image
    uid = uuid.uuid4().hex
    input_path = os.path.join(UPLOAD_FOLDER, f"{uid}_input.jpg")
    file.save(input_path)

    # Run YOLO model
    results = yolo_model(input_path, conf=0.2)
    r = results[0]

    # Draw bounding boxes
    img = r.orig_img
    pil_img = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(pil_img)
    font = ImageFont.load_default()

    boxes = r.boxes.xyxy.cpu().numpy()
    confs = r.boxes.conf.cpu().numpy()
    classes = r.boxes.cls.cpu().numpy().astype(int)

    for (x1, y1, x2, y2), conf, cls in zip(boxes, confs, classes):
        label = f"{r.names[cls]} {conf:.2f}"
        draw.rectangle([x1, y1, x2, y2], outline="red" if cls == 0 else "blue", width=2)
        draw.text((x1, y1 - 10), label, fill="white", font=font)

    # Save annotated image
    output_path = os.path.join(UPLOAD_FOLDER, f"{uid}_result.jpg")
    pil_img.save(output_path)

    # Upload to Cloudinary
    uploaded = cloudinary.uploader.upload(output_path)
    cloud_url = uploaded["secure_url"]

    # Prepare response
    if len(classes) > 0:
        idx = np.argmax(confs)
        label = "Bad Weld" if classes[idx] == 0 else "Good Weld"
        score = f"{confs[idx] * 100:.2f}%"
    else:
        label, score = "None", "0.00%"

    return jsonify({
        "defect": label,
        "score": score,
        "image_url": cloud_url
    })

# ========== Final Score Prediction (XGBoost using only scores) ==========
@app.route('/api/final-predict', methods=['POST'])
def predict_final():
    data = request.get_json()
    task_scores = data.get('task_scores')

    print("Received task_scores:", task_scores)

    if not isinstance(task_scores, list):
        return jsonify({'error': 'task_scores must be a list'}), 400

    # Pad with 0.0 if fewer than 3
    while len(task_scores) < 3:
        task_scores.append(0.0)

    try:
        features = np.array(task_scores).reshape(1, -1)
        prediction = xgb_model.predict(features)[0]
        return jsonify({'predicted_final_score': round(float(prediction), 2)})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ========== Root ==========
@app.route('/')
def home():
    return "<h3>Weld Detection + Final Score API</h3>"

# ========== Run ==========
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
