# 🖼️ Smart Image Processing Pipeline (AWS Serverless)

A production-ready serverless image processing pipeline built with **AWS, Terraform, and Vue 3**. Users upload images directly to S3, which triggers an automated workflow that resizes images, detects labels using AWS Rekognition, and stores metadata in DynamoDB.

---

## 🛠️ Tech Stack

### Frontend
- **Vue 3** (Composition API) - Modern reactive UI
- **Vite** - Fast build tool and dev server
- **Vanilla JavaScript** - No external dependencies

### Backend
- **AWS Lambda** (Python 3.11, ARM64) - Serverless compute
- **AWS Step Functions** - Workflow orchestration
- **AWS S3** - Object storage with presigned URLs
- **AWS Rekognition** - Image label detection
- **AWS DynamoDB** - Metadata storage
- **API Gateway HTTP API** - RESTful endpoints

### Infrastructure
- **Terraform** - Infrastructure as Code
- **IAM** - Secure role-based access control

---

## 🏗️ Architecture

```
┌─────────────┐
│ Vue Frontend│
└──────┬──────┘
       │ POST /upload-url
       ▼
┌─────────────┐     ┌──────────────┐
│API Gateway  │────▶│ Lambda       │
│             │     │ (Presigned)  │
└─────────────┘     └──────────────┘
       │
       │ PUT (Presigned URL)
       ▼
┌─────────────┐
│   S3 Bucket │
└──────┬──────┘
       │ ObjectCreated Event
       ▼
┌─────────────┐
│ Lambda      │
│ (Trigger)    │
└──────┬──────┘
       │ Start Execution
       ▼
┌─────────────────────────────────────┐
│     Step Functions State Machine     │
│  ┌──────────┐  ┌──────────┐  ┌─────┐│
│  │ Resize   │─▶│Rekognition│─▶│Store││
│  │ Image    │  │  Labels   │  │Meta ││
│  └──────────┘  └──────────┘  └─────┘│
└─────────────────────────────────────┘
       │                    │
       ▼                    ▼
┌─────────────┐     ┌─────────────┐
│   S3        │     │  DynamoDB   │
│ (processed)  │     │  (metadata) │
└─────────────┘     └─────────────┘
                            │
                            │ GET /results
                            ▼
                    ┌─────────────┐
                    │ Vue Frontend│
                    │  (Polling)  │
                    └─────────────┘
```

### Key Components

| Component | Purpose |
|-----------|---------|
| **S3 Bucket** | Stores original uploads and processed images. Triggers pipeline on upload. |
| **API Gateway** | Exposes REST endpoints for presigned URL generation and results retrieval. |
| **Lambda Functions** | 5 functions: presigned URL, trigger, resize, Rekognition, store metadata, get results |
| **Step Functions** | Orchestrates the 3-stage pipeline with retry logic and error handling. |
| **Rekognition** | Detects up to 10 labels per image with 70% confidence threshold. |
| **DynamoDB** | Stores image metadata (key, bucket, labels, timestamps) for frontend polling. |

---

## 🔄 End-to-End Flow

1. **Upload Request**: Frontend requests presigned URL from API Gateway
2. **Direct Upload**: User uploads image directly to S3 using presigned URL
3. **Event Trigger**: S3 ObjectCreated event invokes trigger Lambda
4. **Pipeline Execution**: Step Functions orchestrates:
   - **ResizeImage**: Copies image to `processed/` prefix
   - **RekognitionLabels**: Detects labels using AWS Rekognition
   - **StoreMetadata**: Saves results to DynamoDB
5. **Polling**: Frontend polls `GET /results` endpoint until processing completes
6. **Display**: Results displayed with detected labels

---

## 🐛 Top 3 Critical Errors & Fixes

### 1. DynamoDB Primary Key Mismatch + Missing Environment Variable

**Error:**
- DynamoDB table defined with `hash_key = "imageId"` but Lambda code wrote `"image_key"`
- `store_metadata` Lambda referenced `TABLE_NAME` environment variable that wasn't configured

**Impact:** 
- Runtime failures: DynamoDB operations rejected due to missing primary key
- Lambda crashes: `TABLE_NAME` was `None`, causing `Table(None)` initialization errors

**Fix:**
- Changed DynamoDB table hash key from `"imageId"` to `"image_key"` to match Lambda code
- Added `TABLE_NAME` environment variable to `store_metadata` Lambda in Terraform
- Moved DynamoDB table initialization inside handler to avoid import-time failures

**Files Changed:**
- `infrastructure/dynamodb.tf` (line 5)
- `infrastructure/lambda.tf` (lines 55-59)
- `lambdas/store_metadata/handler.py` (moved table creation inside handler)

---

### 2. S3 Presigned URL Signature Mismatch (403 Forbidden)

**Error:**
- Presigned URL generated without `ContentType` in Params
- Frontend sent `Content-Type` header in PUT request
- S3 rejected uploads with 403 Forbidden due to signature mismatch

**Impact:**
- All browser uploads failed silently
- Users couldn't upload images

**Fix:**
- Added `ContentType` parameter to presigned URL generation in Lambda
- Frontend sends matching `Content-Type` header value
- Implemented dynamic content type support (JPEG, PNG, WEBP)

**Files Changed:**
- `lambdas/get_presigned_url/handler.py` (line 19, added ContentType to Params)
- `frontend/src/App.vue` (line 64, sends Content-Type header)

---

### 3. Step Functions Schema Validation Error

**Error:**
- Terraform apply failed with: `"States.ALL must appear alone and at end of list"`
- Retry blocks combined `States.ALL` with other error types: `["States.TaskFailed", "States.Timeout", "States.ALL"]`

**Impact:**
- Infrastructure deployment failures
- State machine couldn't be created

**Fix:**
- Changed all Retry blocks to use only `["States.ALL"]` (covers all error types)
- Removed redundant error type specifications

**Files Changed:**
- `infrastructure/stepfunctions.tf` (lines 51, 71, 91)

---

## ✅ Additional Improvements Made

- **Error Handling**: Added try/except blocks and logging to all Lambda functions
- **Step Functions Resilience**: Added retry policies (3 attempts, exponential backoff) and catch blocks
- **S3 Security**: Enabled server-side encryption (AES256) and CORS configuration
- **Lambda Configuration**: Set timeouts (120s) and memory (512MB) for image processing
- **Frontend UX**: Implemented two-phase polling (active → background) with timeout protection
- **CORS**: Fixed API Gateway and S3 CORS for browser-based uploads

---

## 📁 Project Structure

```
aws-img-pl/
├── infrastructure/          # Terraform IaC
│   ├── main.tf             # Provider configuration
│   ├── variables.tf         # Input variables
│   ├── outputs.tf          # Output values
│   ├── s3.tf               # S3 bucket, CORS, encryption
│   ├── dynamodb.tf         # DynamoDB table
│   ├── lambda.tf           # Lambda function definitions
│   ├── stepfunctions.tf    # Step Functions state machine
│   ├── api-gateway.tf      # API Gateway routes
│   └── iam.tf              # IAM roles and policies
├── lambdas/                # Lambda function code
│   ├── get_presigned_url/  # Generate S3 presigned URLs
│   ├── trigger_step_function/ # S3 event → Step Functions
│   ├── resize_image/       # Copy image to processed/
│   ├── rekognition_labels/ # AWS Rekognition label detection
│   ├── store_metadata/     # Save to DynamoDB
│   └── get_results/        # Query DynamoDB for results
└── frontend/               # Vue 3 application
    └── src/
        └── App.vue         # Main application component
```

---

## 🚀 Planned Next Steps

### High Priority
1. **Fix Key Preservation Issue**: Update `rekognition_labels` Lambda to pass through original `key` field to prevent data loss in Step Functions state
2. **Add Error Handling**: Complete error handling for `resize_image` and `rekognition_labels` Lambdas (currently missing try/except blocks)
3. **CloudWatch Monitoring**: Add alarms for Lambda errors, Step Functions failures, and Rekognition throttling

### Medium Priority
4. **Implement Actual Image Resizing**: Replace file copy with actual image resizing using PIL/Pillow
5. **Add Dead-Letter Queues**: Configure DLQs for failed Lambda invocations and Step Functions executions
6. **Tighten IAM Permissions**: Scope wildcard permissions to specific resources (Step Functions ARN, etc.)
7. **Add Input Validation**: Validate image size, format, and quality before processing

### Nice to Have
8. **User Authentication**: Add AWS Cognito for user management
9. **Image Preview**: Display uploaded images in frontend
10. **Batch Processing**: Support multiple image uploads
11. **CloudFront CDN**: Add CDN for optimized image delivery
12. **S3 Lifecycle Policies**: Automate cleanup of old processed images

---

## 🔧 Setup & Deployment

### Prerequisites
- AWS CLI configured
- Terraform >= 1.5.0
- Node.js >= 20.19.0
- Python 3.11

### Deploy Infrastructure
```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

### Build Lambda Packages
```bash
cd lambdas/<function-name>
zip -r build.zip handler.py
```

### Run Frontend
```bash
cd frontend
npm install
npm run dev
```

---

## 📊 Current Status

✅ **Working Features:**
- End-to-end image upload and processing
- Presigned URL generation with dynamic content types
- Step Functions orchestration with retry logic
- Rekognition label detection
- DynamoDB metadata storage
- Frontend polling with background processing
- CORS configuration for browser uploads

⚠️ **Known Issues:**
- Original upload key (`uploads/<uuid>.jpg`) is dropped in RekognitionLabels step
- Some Lambda functions lack comprehensive error handling
- No monitoring/alarms configured

---

## 📜 License

MIT
