document.addEventListener('DOMContentLoaded', function() {
    const uploadForm = document.getElementById('upload-form');
    const imageUpload = document.getElementById('image-upload');
    const resultContainer = document.getElementById('result-container');
    const errorContainer = document.getElementById('error-container');
    const errorMessage = document.getElementById('error-message');
    const loadingContainer = document.getElementById('loading-container');
    const uploadedImage = document.getElementById('uploaded-image');
    const predictionsList = document.getElementById('predictions-list');

    // 监听表单提交事件
    uploadForm.addEventListener('submit', function(e) {
        e.preventDefault();
        
        // 检查是否选择了文件
        if (!imageUpload.files[0]) {
            showError('请选择一个图片文件');
            return;
        }

        // 检查文件类型
        const fileType = imageUpload.files[0].type;
        if (!fileType.match('image.*')) {
            showError('请选择有效的图片文件 (JPEG, PNG, etc.)');
            return;
        }

        // 隐藏之前的结果和错误
        resultContainer.style.display = 'none';
        errorContainer.style.display = 'none';
        
        // 显示加载指示器
        loadingContainer.style.display = 'block';

        // 创建FormData对象
        const formData = new FormData();
        formData.append('file', imageUpload.files[0]);

        // 发送AJAX请求
        fetch('/upload', {
            method: 'POST',
            body: formData
        })
        .then(response => response.json())
        .then(data => {
            // 隐藏加载指示器
            loadingContainer.style.display = 'none';

            if (data.error) {
                showError(data.error);
                return;
            }

            // 显示上传的图片
            uploadedImage.src = '/static/' + data.image_path;
            
            // 清空并填充预测结果
            predictionsList.innerHTML = '';
            
            data.predictions.forEach(prediction => {
                const predictionItem = document.createElement('div');
                predictionItem.className = 'prediction-item';
                
                const label = document.createElement('div');
                label.className = 'prediction-label';
                label.textContent = prediction.label;
                
                const progressContainer = document.createElement('div');
                progressContainer.className = 'progress';
                
                const progressBar = document.createElement('div');
                progressBar.className = 'progress-bar';
                progressBar.style.width = prediction.probability + '%';
                progressBar.setAttribute('role', 'progressbar');
                progressBar.setAttribute('aria-valuenow', prediction.probability);
                progressBar.setAttribute('aria-valuemin', '0');
                progressBar.setAttribute('aria-valuemax', '100');
                
                const progressLabel = document.createElement('span');
                progressLabel.className = 'progress-label';
                progressLabel.textContent = prediction.probability.toFixed(2) + '%';
                
                // 根据概率设置颜色
                if (prediction.probability > 70) {
                    progressBar.classList.add('bg-success');
                } else if (prediction.probability > 40) {
                    progressBar.classList.add('bg-info');
                } else if (prediction.probability > 20) {
                    progressBar.classList.add('bg-warning');
                } else {
                    progressBar.classList.add('bg-danger');
                }
                
                progressBar.appendChild(progressLabel);
                progressContainer.appendChild(progressBar);
                predictionItem.appendChild(label);
                predictionItem.appendChild(progressContainer);
                
                predictionsList.appendChild(predictionItem);
            });

            // 显示结果容器
            resultContainer.style.display = 'block';
        })
        .catch(error => {
            loadingContainer.style.display = 'none';
            showError('上传过程中发生错误: ' + error.message);
        });
    });