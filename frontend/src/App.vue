<script setup>
import { ref, onUnmounted } from 'vue'

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || 'https://your-api-id.execute-api.us-east-1.amazonaws.com'
const selectedFile = ref(null)
const isUploading = ref(false)
const uploadStatus = ref('')
const objectKey = ref(null)
const labels = ref([])

// Processing state: PROCESSING_ACTIVE | PROCESSING_BACKGROUND | COMPLETE | FAILED
const processingState = ref(null)
const MAX_ACTIVE_POLLING_MS = 15000 // 15 seconds - active polling phase
const MAX_TOTAL_POLLING_MS = 300000 // 5 minutes - hard timeout
const POLLING_INTERVAL_MS = 3000 // 3 seconds

let pollingInterval = null
let pollingStartTime = null
let activePollingStartTime = null
let activePollingTimeout = null
let currentImageKey = null

const handleFileSelect = (event) => {
  selectedFile.value = event.target.files[0]
  uploadStatus.value = ''
  labels.value = []
  objectKey.value = null
  processingState.value = null
  stopPolling()
}

const getPresignedUrl = async (contentType) => {
  try {
    const response = await fetch(`${apiBaseUrl}/upload-url`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ contentType })
    })
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    const data = await response.json()
    return { uploadUrl: data.uploadUrl, key: data.key }
  } catch (error) {
    console.error('Error getting presigned URL:', error)
    uploadStatus.value = 'Error: Failed to get upload URL'
    return null
  }
}

const uploadImage = async () => {
  if (!selectedFile.value) {
    uploadStatus.value = 'Please select an image first'
    return
  }

  isUploading.value = true
  uploadStatus.value = 'Getting upload URL...'

  try {
    const presignedData = await getPresignedUrl(selectedFile.value.type)
    if (!presignedData) {
      isUploading.value = false
      return
    }

    uploadStatus.value = 'Uploading image...'

    const uploadResponse = await fetch(presignedData.uploadUrl, {
      method: 'PUT',
      body: selectedFile.value,
      headers: {
        'Content-Type': selectedFile.value.type
      }
    })

    if (uploadResponse.ok) {
      objectKey.value = presignedData.key
      uploadStatus.value = '✓ Image uploaded! Processing pipeline started. Waiting for results...'
      startPolling(presignedData.key)
    } else {
      uploadStatus.value = 'Error: Upload failed'
    }
  } catch (error) {
    console.error('Upload error:', error)
    uploadStatus.value = 'Error: Upload failed'
  } finally {
    isUploading.value = false
  }
}

const fetchResults = async (imageKey) => {
  try {
    const response = await fetch(`${apiBaseUrl}/results?image_key=${encodeURIComponent(imageKey)}`)
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    const data = await response.json()
    return data
  } catch (error) {
    console.error('Error fetching results:', error)
    return null
  }
}

const stopPolling = () => {
  if (pollingInterval) {
    clearInterval(pollingInterval)
    pollingInterval = null
  }
  if (activePollingTimeout) {
    clearTimeout(activePollingTimeout)
    activePollingTimeout = null
  }
  pollingStartTime = null
  activePollingStartTime = null
}

const performPoll = async (imageKey) => {
  // Check total timeout (prevents infinite polling across all phases)
  if (pollingStartTime) {
    const totalElapsed = Date.now() - pollingStartTime
    if (totalElapsed > MAX_TOTAL_POLLING_MS) {
      processingState.value = 'FAILED'
      uploadStatus.value = 'Error: Processing timeout - maximum wait time exceeded'
      stopPolling()
      return
    }
  }
  
  const response = await fetchResults(imageKey)
  
  if (!response) {
    return // Continue polling on network error
  }
  
  if (response.status === "COMPLETE" && response.results && response.results.labels) {
    labels.value = response.results.labels
    uploadStatus.value = '✓ Processing complete!'
    processingState.value = 'COMPLETE'
    stopPolling()
  } else if (response.status === "FAILED") {
    uploadStatus.value = `Error: ${response.reason || 'Processing failed'}`
    processingState.value = 'FAILED'
    stopPolling()
  } else if (response.status === "PROCESSING") {
    // Check if we should transition to background phase
    if (processingState.value === 'PROCESSING_ACTIVE' && activePollingStartTime) {
      const activeElapsed = Date.now() - activePollingStartTime
      if (activeElapsed >= MAX_ACTIVE_POLLING_MS) {
        // Transition to background: stop polling, backend continues processing
        stopPolling()
        processingState.value = 'PROCESSING_BACKGROUND'
        uploadStatus.value = 'Processing is taking longer than usual...'
      }
    }
  }
}

const startPolling = (imageKey) => {
  // Stop any existing polling
  stopPolling()
  
  currentImageKey = imageKey
  processingState.value = 'PROCESSING_ACTIVE'
  pollingStartTime = Date.now()
  activePollingStartTime = Date.now()
  
  // Poll immediately on start
  performPoll(imageKey)
  
  // Set up interval for active polling phase
  pollingInterval = setInterval(() => {
    performPoll(imageKey)
  }, POLLING_INTERVAL_MS)
  
  // Set timeout to transition to background after active phase
  // Backgrounding after 15s prevents excessive polling while backend continues processing
  activePollingTimeout = setTimeout(() => {
    if (processingState.value === 'PROCESSING_ACTIVE') {
      stopPolling()
      processingState.value = 'PROCESSING_BACKGROUND'
      uploadStatus.value = 'Processing is taking longer than usual...'
    }
  }, MAX_ACTIVE_POLLING_MS)
}

const resumePolling = () => {
  if (!currentImageKey) return
  
  // Resume active polling phase
  processingState.value = 'PROCESSING_ACTIVE'
  activePollingStartTime = Date.now()
  
  // Poll immediately on resume
  performPoll(currentImageKey)
  
  // Set up interval for active polling phase
  pollingInterval = setInterval(() => {
    performPoll(currentImageKey)
  }, POLLING_INTERVAL_MS)
  
  // Set timeout to transition to background again if needed
  activePollingTimeout = setTimeout(() => {
    if (processingState.value === 'PROCESSING_ACTIVE') {
      stopPolling()
      processingState.value = 'PROCESSING_BACKGROUND'
      uploadStatus.value = 'Processing is taking longer than usual...'
    }
  }, MAX_ACTIVE_POLLING_MS)
}

onUnmounted(() => {
  stopPolling()
})
</script>

<template>
  <div class="container">
    <header>
      <h1>🖼️ Smart Image Processing Pipeline</h1>
      <p class="subtitle">Serverless AWS architecture for automated image analysis</p>
    </header>

    <section class="architecture-section">
      <h2>System Architecture</h2>
      <div class="diagram">
        <div class="diagram-flow">
          <!-- Vue Frontend -->
          <div class="diagram-box frontend">
            <div class="box-label">Vue Frontend</div>
          </div>
          <div class="arrow-down">▼<br>POST /upload-url</div>
          
          <!-- API Gateway → Lambda -->
          <div class="diagram-row">
            <div class="diagram-box api">
              <div class="box-label">API Gateway</div>
            </div>
            <div class="arrow-right">→</div>
            <div class="diagram-box lambda">
              <div class="box-label">Lambda</div>
              <div class="box-sublabel">Presigned URL</div>
            </div>
          </div>
          
          <div class="arrow-down">▼<br>PUT (Presigned URL)</div>
          
          <!-- S3 Bucket -->
          <div class="diagram-box s3">
            <div class="box-label">S3 Bucket</div>
          </div>
          <div class="arrow-down">▼<br>ObjectCreated Event</div>
          
          <!-- Lambda Trigger -->
          <div class="diagram-box lambda">
            <div class="box-label">Lambda</div>
            <div class="box-sublabel">Trigger</div>
          </div>
          <div class="arrow-down">▼<br>StartExecution</div>
          
          <!-- Step Functions -->
          <div class="diagram-box stepfn">
            <div class="box-label">Step Functions State Machine</div>
            <div class="box-sublabel">Resize → Rekognition → Store Meta</div>
          </div>
          
          <!-- Arrows from Step Functions to S3 and DynamoDB -->
          <div class="diagram-row arrows-from-stepfn">
            <div class="arrow-down">▼</div>
            <div class="arrow-down">▼</div>
          </div>
          
          <!-- S3 and DynamoDB side by side -->
          <div class="diagram-row">
            <div class="diagram-box s3">
              <div class="box-label">S3</div>
              <div class="box-sublabel">(processed)</div>
            </div>
            <div class="diagram-box dynamodb">
              <div class="box-label">DynamoDB</div>
              <div class="box-sublabel">(metadata)</div>
            </div>
          </div>
          
          <!-- GET /results from DynamoDB (aligned right) -->
          <div class="arrow-down arrow-from-right">▼<br>GET /results</div>
          
          <!-- Vue Frontend Polling -->
          <div class="diagram-box frontend diagram-right">
            <div class="box-label">Vue Frontend</div>
            <div class="box-sublabel">(Polling)</div>
          </div>
        </div>
      </div>
    </section>

    <main class="upload-section">
      <div class="upload-card">
        <div class="file-input-wrapper">
          <input
            id="file-input"
            type="file"
            accept="image/jpeg,image/jpg,image/png,image/webp"
            @change="handleFileSelect"
            class="file-input"
          />
          <label for="file-input" class="file-label">
            {{ selectedFile ? selectedFile.name : 'Choose an image...' }}
          </label>
        </div>

        <button
          @click="uploadImage"
          :disabled="!selectedFile || isUploading"
          class="btn-primary"
        >
          {{ isUploading ? 'Uploading...' : 'Upload Image' }}
        </button>

        <div v-if="uploadStatus" class="status-message" :class="{ error: uploadStatus.startsWith('Error') }">
          {{ uploadStatus }}
        </div>

        <div v-if="processingState === 'PROCESSING_ACTIVE'" class="polling-indicator">
          ⏳ Polling for results...
        </div>

        <div v-if="processingState === 'PROCESSING_BACKGROUND'" class="background-message">
          <p>This is taking a bit longer than usual. You can safely leave this page and check back shortly.</p>
          <button @click="resumePolling" class="btn-secondary">
            Check again
          </button>
        </div>

        <div v-if="labels.length > 0" class="results-section">
          <h3>Detected Labels:</h3>
          <ul class="labels-list">
            <li v-for="(label, index) in labels" :key="index" class="label-item">
              {{ label }}
            </li>
          </ul>
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: #f7fafc;
  min-height: 100vh;
}

header {
  text-align: center;
  margin-bottom: 3rem;
  color: #2d3748;
}

h1 {
  font-size: 2.5rem;
  margin-bottom: 0.5rem;
  font-weight: 700;
  color: #1a202c;
}

.subtitle {
  font-size: 1.1rem;
  color: #718096;
  font-weight: 400;
}

/* Architecture Diagram */
.architecture-section {
  background: white;
  border-radius: 12px;
  padding: 2rem;
  margin-bottom: 2rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  border: 1px solid #e2e8f0;
}

.architecture-section h2 {
  text-align: center;
  color: #2d3748;
  margin-bottom: 2rem;
  font-size: 1.5rem;
  font-weight: 600;
}

.diagram {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  align-items: center;
}

.diagram-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  justify-content: center;
}

.diagram-box {
  background: #edf2f7;
  color: #2d3748;
  padding: 1rem 1.5rem;
  border-radius: 8px;
  text-align: center;
  min-width: 120px;
  border: 1px solid #cbd5e0;
  transition: all 0.2s;
}

.diagram-box:hover {
  background: #e2e8f0;
  border-color: #a0aec0;
}

.diagram-box.frontend {
  background: #ebf8ff;
  border-color: #bee3f8;
}

.diagram-box.api {
  background: #fef5e7;
  border-color: #fbd38d;
}

.diagram-box.lambda {
  background: #e6fffa;
  border-color: #81e6d9;
}

.diagram-box.s3 {
  background: #f0fff4;
  border-color: #9ae6b4;
}

.diagram-box.stepfn {
  background: #faf5ff;
  border-color: #d6bcfa;
}

.diagram-box.rekognition {
  background: #fffaf0;
  border-color: #f6e05e;
}

.diagram-box.dynamodb {
  background: #edf2f7;
  border-color: #cbd5e0;
}

.box-icon {
  font-size: 1.5rem;
  margin-bottom: 0.25rem;
}

.box-label {
  font-weight: 600;
  font-size: 0.9rem;
}

.box-sublabel {
  font-size: 0.75rem;
  opacity: 0.9;
  margin-top: 0.25rem;
}

.arrow {
  font-size: 1.5rem;
  color: #a0aec0;
  font-weight: 500;
}

/* Upload Section */
.upload-section {
  display: flex;
  justify-content: center;
}

.upload-card {
  background: white;
  border-radius: 12px;
  padding: 2.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  border: 1px solid #e2e8f0;
  width: 100%;
  max-width: 600px;
}

.file-input-wrapper {
  margin-bottom: 1.5rem;
}

.file-input {
  display: none;
}

.file-label {
  display: block;
  padding: 1.5rem;
  border: 2px dashed #cbd5e0;
  border-radius: 8px;
  text-align: center;
  cursor: pointer;
  color: #4a5568;
  font-weight: 500;
  transition: all 0.2s ease;
  background: #f7fafc;
}

.file-label:hover {
  background: #edf2f7;
  border-color: #a0aec0;
  color: #2d3748;
}

.btn-primary {
  background: #4a5568;
  color: white;
  border: none;
  padding: 1rem 2rem;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  width: 100%;
  transition: all 0.2s ease;
}

.btn-primary:hover:not(:disabled) {
  background: #2d3748;
}

.btn-primary:disabled {
  background: #cbd5e0;
  color: #a0aec0;
  cursor: not-allowed;
}

.status-message {
  margin-top: 1rem;
  padding: 1rem;
  border-radius: 8px;
  background: #f0fff4;
  color: #22543d;
  text-align: center;
  font-weight: 500;
  border: 1px solid #9ae6b4;
}

.status-message.error {
  background: #fff5f5;
  color: #742a2a;
  border-color: #fc8181;
}

.polling-indicator {
  margin-top: 1rem;
  text-align: center;
  color: #718096;
  font-style: italic;
  font-weight: 400;
}

.background-message {
  margin-top: 1.5rem;
  padding: 1.5rem;
  background: #fffaf0;
  border: 1px solid #f6e05e;
  border-radius: 8px;
  text-align: center;
}

.background-message p {
  margin: 0 0 1rem 0;
  color: #744210;
  font-weight: 400;
}

.btn-secondary {
  background: white;
  color: #4a5568;
  border: 1px solid #cbd5e0;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-size: 0.95rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-secondary:hover {
  background: #f7fafc;
  border-color: #a0aec0;
  color: #2d3748;
}

.results-section {
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 2px solid #e2e8f0;
}

.results-section h3 {
  margin-bottom: 1rem;
  font-size: 1.3rem;
  color: #2d3748;
  font-weight: 600;
}

.labels-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 0.75rem;
}

.label-item {
  padding: 0.75rem 1rem;
  background: #f7fafc;
  border-radius: 6px;
  text-align: center;
  font-weight: 500;
  color: #2d3748;
  border: 1px solid #e2e8f0;
  transition: all 0.2s ease;
}

.label-item:hover {
  background: #edf2f7;
  border-color: #cbd5e0;
}

.architecture-section {
  margin: 2rem 0 3rem 0;
  padding: 2rem;
  background: #f7fafc;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
}

.architecture-section h2 {
  margin: 0 0 1.5rem 0;
  font-size: 1.5rem;
  color: #2d3748;
  font-weight: 600;
  text-align: center;
}

.diagram {
  display: flex;
  justify-content: center;
  align-items: center;
}

.diagram-flow {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
}

.diagram-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin: 0.5rem 0;
  position: relative;
}

.arrows-from-stepfn {
  gap: 0;
  justify-content: space-between;
  width: 100%;
  max-width: 400px;
}

.arrows-from-stepfn .arrow-down {
  flex: 1;
  padding: 0.25rem 0;
}

.diagram-box {
  padding: 1rem 1.5rem;
  background: white;
  border: 2px solid #cbd5e0;
  border-radius: 8px;
  text-align: center;
  min-width: 150px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.diagram-box.frontend {
  border-color: #4299e1;
  background: #ebf8ff;
}

.diagram-box.api {
  border-color: #ed8936;
  background: #fffaf0;
}

.diagram-box.lambda {
  border-color: #48bb78;
  background: #f0fff4;
}

.diagram-box.s3 {
  border-color: #9f7aea;
  background: #faf5ff;
}

.diagram-box.stepfn {
  border-color: #f56565;
  background: #fff5f5;
}

.diagram-box.dynamodb {
  border-color: #718096;
  background: #f7fafc;
}

.box-label {
  font-weight: 600;
  color: #2d3748;
  font-size: 0.95rem;
}

.box-sublabel {
  font-size: 0.8rem;
  color: #718096;
  margin-top: 0.25rem;
  font-weight: 400;
}

.arrow-down {
  color: #4a5568;
  font-size: 0.85rem;
  font-weight: 500;
  padding: 0.5rem 0;
  text-align: center;
  line-height: 1.4;
}

.arrow-down br {
  display: block;
  margin: 0.25rem 0;
}

.arrow-right {
  color: #4a5568;
  font-size: 1.5rem;
  font-weight: 600;
  padding: 0 0.5rem;
  display: flex;
  align-items: center;
}

.arrow-from-right {
  align-self: flex-end;
  margin-right: 25%;
}

.diagram-right {
  align-self: flex-end;
  margin-right: 25%;
}
</style>
