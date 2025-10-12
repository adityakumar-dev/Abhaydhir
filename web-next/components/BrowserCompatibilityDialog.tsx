"use client"

import { useState, useEffect } from 'react'
import { X } from 'lucide-react'

export function BrowserCompatibilityDialog() {
  const [isOpen, setIsOpen] = useState(false)

  useEffect(() => {
    // Check if browser is Chrome or Edge
    const isChrome = /Chrome/.test(navigator.userAgent) && !/Edge/.test(navigator.userAgent)
    const isEdge = /Edge/.test(navigator.userAgent)
    
    // Show dialog if not Chrome or Edge
    if (!isChrome && !isEdge) {
      setIsOpen(true)
    }
  }, [])

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg p-8 w-full max-w-md relative">
        <button 
          onClick={() => setIsOpen(false)}
          className="absolute top-4 right-4 text-gray-500 hover:text-gray-700"
        >
          <X size={24} />
        </button>

        <div className="text-center">
          <h2 className="text-2xl font-bold mb-4 text-gray-800">Browser Compatibility Notice</h2>
          <div className="mb-6">
            <p className="text-gray-600 mb-2">For the best experience, please use:</p>
            <div className="flex justify-center gap-4">
              <img src="/images/chrome-logo.png" alt="Chrome" className="w-12 h-12" />
              <img src="/images/edge-logo.png" alt="Edge" className="w-12 h-12" />
            </div>
          </div>
          <p className="text-gray-600 mb-6">
            Some features may not work properly in other browsers. We recommend using Google Chrome or Microsoft Edge for the best experience.
          </p>
          <button
            onClick={() => setIsOpen(false)}
            className="bg-yellow-600 text-white px-6 py-2 rounded-md hover:bg-yellow-700 transition duration-300"
          >
            I Understand
          </button>
        </div>
      </div>
    </div>
  )
} 