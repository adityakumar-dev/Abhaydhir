"use client"

import Image from "next/image"
import { useState } from "react"
import { X } from "lucide-react"

export default function GalleryPage() {
  const [selectedImage, setSelectedImage] = useState<string | null>(null)

  const galleryItems = [
    {
      id: 1,
      type: "image",
      src: "/images/spring_festival/image1.jpg",
      title: "Spring Festival 2024 - Main Stage",
      description: "Cultural performances at the main stage during Spring Festival 2024"
    },
    {
      id: 2,
      type: "image",
      src: "/images/spring_festival/image2.jpg",
      title: "Spring Festival 2024 - Exhibition",
      description: "Art and craft exhibition showcasing local talent"
    },
    {
      id: 3,
      type: "image",
      src: "/images/spring_festival/image3.jpg",
      title: "Spring Festival 2024 - Food Court",
      description: "Traditional food stalls offering local delicacies"
    },
    {
      id: 4,
      type: "image",
      src: "/images/spring_festival/image4.jpg",
      title: "Spring Festival 2024 - Cultural Dance",
      description: "Traditional dance performances by local artists"
    },
    {
      id: 5,
      type: "image",
      src: "/images/spring_festival/image5.jpg",
      title: "Spring Festival 2024 - Workshop",
      description: "Interactive workshops for visitors"
    },
    {
      id: 6,
      type: "image",
      src: "/images/spring_festival/image6.jpg",
      title: "Spring Festival 2024 - Closing Ceremony",
      description: "Grand finale of Spring Festival 2024"
    }
  ]

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
      {/* Hero Section */}
      <header className="relative bg-cover bg-center h-[40vh]" style={{ backgroundImage: 'linear-gradient(rgba(0, 0, 0, 0.7), rgba(0, 0, 0, 0.7)), url("/images/spring_festival/image1.jpg")' }}>
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="text-center text-white">
            <h1 className="text-4xl md:text-5xl font-bold mb-4">Gallery</h1>
            <p className="text-xl">Explore moments from our events</p>
          </div>
        </div>
      </header>

      {/* Gallery Section */}
      <section className="py-16">
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {galleryItems.map((item) => (
              <div
                key={item.id}
                className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow cursor-pointer"
                onClick={() => setSelectedImage(item.src)}
              >
                <div className="relative h-64">
                  <Image
                    src={item.src}
                    alt={item.title}
                    fill
                    className="object-cover"
                  />
                </div>
                <div className="p-6">
                  <h3 className="text-xl font-semibold text-gray-800 mb-2">{item.title}</h3>
                  <p className="text-gray-600">{item.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Image Modal */}
      {selectedImage && (
        <div className="fixed inset-0 bg-black bg-opacity-90 z-50 flex items-center justify-center p-4">
          <button
            className="absolute top-4 right-4 text-white hover:text-gray-300"
            onClick={() => setSelectedImage(null)}
          >
            <X className="w-8 h-8" />
          </button>
          <div className="relative w-full max-w-4xl h-[80vh]">
            <Image
              src={selectedImage}
              alt="Selected image"
              fill
              className="object-contain"
            />
          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-8">
        <div className="container mx-auto px-4">
          <div className="flex flex-col md:flex-row justify-between items-center">
            <div className="flex items-center gap-3 brightness-0 invert mb-4 md:mb-0">
              <Image src="/images/emblem_white.svg" alt="Government Logo" width={40} height={40} className="w-8 md:w-12" />
              <div className="flex flex-col">
                <p className="text-sm md:text-lg text-white">राजभवन उत्तराखंड</p>
                <h1 className="text-base md:text-xl text-white font-bold">RAJBHAWAN UTTARAKHAND</h1>
                <p className="text-xs text-yellow-400">Visitor & Entry Management System</p>
              </div>
            </div>
            <div className="text-center md:text-right">
              <p className="text-sm text-gray-400">&copy; 2025 All rights reserved.</p>
              <p className="text-sm text-gray-400">Developed by Uttarakhand Technical University</p>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
} 