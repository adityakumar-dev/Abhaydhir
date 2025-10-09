"use client"

import { useEffect, useState } from "react"

export function LoadingBar() {
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    // Start with a small progress
    setProgress(20)

    // Move to 80% quickly
    const timer1 = setTimeout(() => {
      setProgress(80)
    }, 200)

    // Complete the progress after content should be loaded
    const timer2 = setTimeout(() => {
      setProgress(100)
    }, 500)

    return () => {
      clearTimeout(timer1)
      clearTimeout(timer2)
    }
  }, [])

  return (
    <div className="fixed top-0 left-0 w-full h-1 z-50">
      <div
        className="h-full bg-yellow-500 transition-all duration-500 ease-out shadow-lg"
        style={{ 
          width: `${progress}%`,
          boxShadow: '0 0 8px rgba(250, 204, 21, 0.7)' 
        }}
      />
    </div>
  )
} 