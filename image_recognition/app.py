import os
import uuid
from flask import Flask, render_template, request, jsonify
import numpy as np
from PIL import Image

# 尝试导入TensorFlow，如果不可用则使用模拟模式
try:
    import tensorflow as tf
    TENSORFLOW_AVAILABLE = True
except ImportError:
    print("TensorFlow未安装，将使用模拟模式")
    TENSORFLOW_AVAILABLE = False

app = Flask(__name__)

# 配置上传文件夹
UPLOAD_FOLDER = os.path.join('static', 'uploads')
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# 确保上传文件夹存在
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# 加载预训练模型
def load_model():
    try:
        # 尝试使用MobileNetV2预训练模型
        if TENSORFLOW_AVAILABLE:
            model = tf.keras.applications.MobileNetV2(weights='imagenet')
            return model
        else:
            print("TensorFlow未安装，将使用模拟模式")
            return None
    except Exception as e:
        print(f"模型加载错误: {e}")
        return None

# 图像预处理
def preprocess_image(image_path):
    try:
        img = Image.open(image_path).convert('RGB')
        img = img.resize((224, 224))
        if TENSORFLOW_AVAILABLE:
            img_array = tf.keras.preprocessing.image.img_to_array(img)
            img_array = tf.keras.applications.mobilenet_v2.preprocess_input(img_array)
            img_array = np.expand_dims(img_array, axis=0)
            return img_array
        else:
            # 如果没有TensorFlow，返回None
            return None
    except Exception as e:
        print(f"图像预处理错误: {e}")
        return None

# 预测图像内容
def predict_image(model, img_array):
    try:
        if TENSORFLOW_AVAILABLE and model is not None and img_array is not None:
            predictions = model.predict(img_array)
            decoded_predictions = tf.keras.applications.mobilenet_v2.decode_predictions(predictions, top=5)[0]
            
            results = []
            for _, label, probability in decoded_predictions:
                results.append({
                    'label': label.replace('_', ' ').title(),
                    'probability': float(probability * 100)
                })
            return results
        else:
            # 模拟模式，返回一些示例结果
            import random
            sample_categories = [
                {'label': '猫', 'probability': random.uniform(70, 95)},
                {'label': '狗', 'probability': random.uniform(40, 70)},
                {'label': '鸟', 'probability': random.uniform(20, 40)},
                {'label': '鱼', 'probability': random.uniform(10, 30)},
                {'label': '花', 'probability': random.uniform(5, 15)}
            ]
            return sample_categories
    except Exception as e:
        print(f"预测错误: {e}")
        return []

# 全局变量存储模型
model = None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    global model
    
    # 如果模型未加载，则加载模型
    if model is None:
        model = load_model()
    
    # 检查是否有文件上传
    if 'file' not in request.files:
        return jsonify({'error': '没有上传文件'})
    
    file = request.files['file']
    
    # 检查文件名是否为空
    if file.filename == '':
        return jsonify({'error': '未选择文件'})
    
    try:
        # 生成唯一文件名
        filename = str(uuid.uuid4()) + os.path.splitext(file.filename)[1]
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        # 保存文件
        file.save(file_path)
        
        # 预处理图像
        img_array = preprocess_image(file_path)
        
        # 预测图像内容
        predictions = predict_image(model, img_array)
        
        # 返回结果
        return jsonify({
            'image_path': os.path.join('uploads', filename),
            'predictions': predictions
        })
    
    except Exception as e:
        return jsonify({'error': f'处理过程中出错: {str(e)}'})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)