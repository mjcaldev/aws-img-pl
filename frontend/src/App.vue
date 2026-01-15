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
      <p>
        Visit <a href="https://vuejs.org/" target="_blank" rel="noopener">vuejs.org</a> to read the
        documentation
      </p>
    </header>

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
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
}

header {
  text-align: center;
  margin-bottom: 2rem;
}

h1 {
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

.upload-section {
  display: flex;
  justify-content: center;
}

.upload-card {
  background: white;
  border-radius: 8px;
  padding: 2rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 500px;
}

.file-input-wrapper {
  margin-bottom: 1.5rem;
}

.file-input {
  display: none;
}

.file-label {
  display: block;
  padding: 1rem;
  border: 2px dashed #3498db;
  border-radius: 6px;
  text-align: center;
  cursor: pointer;
  color: #3498db;
}

.file-label:hover {
  background: #ecf0f1;
}

.btn-primary {
  background: #3498db;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  width: 100%;
  transition: background 0.3s;
}

.btn-primary:hover:not(:disabled) {
  background: #2980b9;
}

.btn-primary:disabled {
  background: #bdc3c7;
  cursor: not-allowed;
}

.status-message {
  margin-top: 1rem;
  padding: 0.75rem;
  border-radius: 4px;
  background: #d4edda;
  color: #155724;
  text-align: center;
}

.status-message.error {
  background: #f8d7da;
  color: #721c24;
}

.polling-indicator {
  margin-top: 1rem;
  text-align: center;
  color: #7f8c8d;
  font-style: italic;
}

.background-message {
  margin-top: 1.5rem;
  padding: 1rem;
  background: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 6px;
  text-align: center;
}

.background-message p {
  margin: 0 0 1rem 0;
  color: #856404;
}

.btn-secondary {
  background: white;
  color: #3498db;
  border: 2px solid #3498db;
  padding: 0.6rem 1.5rem;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s ease;
}

.btn-secondary:hover {
  background: #ecf0f1;
  border-color: #2980b9;
}

.results-section {
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 1px solid #e0e0e0;
}

.results-section h3 {
  margin-bottom: 1rem;
  font-size: 1.2rem;
}

.labels-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.label-item {
  padding: 0.5rem;
  margin-bottom: 0.5rem;
  background: #f8f9fa;
  border-radius: 4px;
}
</style>
