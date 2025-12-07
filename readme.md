# 🖼️ Smart Image Processing Pipeline (AWS Serverless)

A fully serverless image-processing workflow built with **AWS + Terraform + Vue**.  
Users upload images → the backend automatically resizes, analyzes, and stores metadata using an event-driven architecture.

---

## 🚀 Features

- Direct uploads to S3 using presigned URLs  
- Event-driven workflow: **S3 → Lambda → Step Functions**  
- Automatic image resizing  
- Rekognition label detection  
- Metadata stored in DynamoDB  
- Vue frontend for uploading & feedback  
- Terraform-managed infrastructure  

---

## 🧩 AWS Components

| Service        | Purpose                                                         |
|----------------|-----------------------------------------------------------------|
| **S3**         | Stores original + processed images; triggers workflow           |
| **Lambda**     | Four functions: trigger workflow, resize image, analyze labels, store metadata |
| **Step Functions** | Orchestrates the pipeline in sequence                      |
| **Rekognition**| Detects image labels                                            |
| **DynamoDB**   | Stores metadata for each processed image                        |
| **API Gateway**| Issues presigned URLs via Lambda                                |
| **IAM**        | Secure roles for all components                                 |

---

## ✅ End-to-End Flow

1. Frontend requests a **presigned URL**  
2. User uploads an image directly to **S3**  
3. S3 triggers the **trigger_step_function** Lambda  
4. Step Functions workflow executes:  
   - Resize image  
   - Detect labels  
   - Store metadata in DynamoDB  
5. Frontend can optionally fetch metadata and display results  

---

## 📌 Future Improvements

- Add SNS/SES notifications  
- Add moderation workflows using Rekognition  
- Add Cognito for user authentication  
- Add CloudFront CDN for optimized delivery  
- Add frontend metadata viewer  
- Add support for vector/image similarity search  

---

## Struture
aws-img-pl/
  infrastructure/
    main.tf
    variables.tf
    outputs.tf
    s3.tf
    dynamodb.tf
    iam.tf
    lambda.tf
    stepfunctions.tf
    api_gateway.tf
  lambdas/
    trigger_step_function/
      handler.py
      requirements.txt
    resize_image/
      handler.py
      requirements.txt
    rekognition_labels/
      handler.py
      requirements.txt
    store_metadata/
      handler.py
      requirements.txt
  frontend/
    # Vue + Vite app

---

## 📜 License

MIT
