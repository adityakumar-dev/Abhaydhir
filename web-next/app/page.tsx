"use client"

import Link from "next/link"
import Image from "next/image"
import { useState } from "react"
import { LoadingBar } from "@/components/loading-bar"

export default function LandingPage() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 via-white to-green-50">
      <LoadingBar />
      
      {/* Navigation Bar */}
      <nav className="bg-gradient-to-r from-amber-700 to-orange-700 backdrop-blur-md shadow-lg sticky top-0 z-50">
        <div className="container mx-auto px-4 py-3">
          <div className="flex items-center justify-between">
            {/* Logo */}
            <div className="flex items-center space-x-2">
              {/* <Image src="/images/emblem_white.svg" alt="Logo" width={40} height={40} 
                className="w-8 h-8 md:w-10 md:h-10" /> */}
              <div className="flex flex-col">
                <p className="text-xs md:text-sm text-white font-medium">Visitor & Entry</p>
                <h1 className="text-sm md:text-lg text-white font-bold">Management System</h1>
              </div>
            </div>

            {/* Desktop Navigation */}
            <div className="hidden md:flex items-center space-x-8">
              {/* <Link href="/about" className="text-white hover:text-amber-100 transition-colors font-medium">About</Link> */}
              <Link href="/vasontutsav2025" className="text-white hover:text-amber-100 transition-colors font-medium">Past Events</Link>
              <Link href="/register/19" className="bg-white text-amber-700 px-6 py-2 rounded-full hover:bg-amber-50 transition font-semibold">Register</Link>
              <Link href="/abhaydhir" className="text-white hover:text-amber-100 transition-colors font-medium">App</Link>
            </div>

            {/* Mobile Menu Button */}
            <button 
              className="md:hidden text-white p-2 focus:outline-none"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            >
              {mobileMenuOpen ? (
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              ) : (
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              )}
            </button>
          </div>

          {/* Mobile Navigation */}
          {mobileMenuOpen && (
            <div className="md:hidden mt-4 pb-4 border-t border-white/20">
              <div className="flex flex-col space-y-3 pt-3">
                {/* <Link href="/about" className="text-white hover:text-amber-100 transition-colors px-2 py-2" onClick={() => setMobileMenuOpen(false)}>About</Link> */}
                <Link href="/features" className="text-white hover:text-amber-100 transition-colors px-2 py-2" onClick={() => setMobileMenuOpen(false)}>Features</Link>
                <Link href="/vasontutsav2025" className="text-white hover:text-amber-100 transition-colors px-2 py-2" onClick={() => setMobileMenuOpen(false)}>Past Events</Link>
                <Link href="/register/14" className="text-white hover:text-amber-100 transition-colors px-2 py-2" onClick={() => setMobileMenuOpen(false)}>Register</Link>
                <Link href="/abhaydhir" className="text-white hover:text-amber-100 transition-colors px-2 py-2" onClick={() => setMobileMenuOpen(false)}>App</Link>
              </div>
            </div>
          )}
        </div>
      </nav>

      {/* Hero Section */}
      <header className="relative h-screen flex items-center justify-center overflow-hidden bg-gradient-to-br from-amber-50 via-white to-green-50">
        {/* Floral Background Elements */}
        <div className="absolute inset-0 overflow-hidden">
          <div className="absolute top-10 left-5 w-32 h-32 opacity-10 animate-pulse">
            <svg viewBox="0 0 100 100" className="w-full h-full text-amber-600">
              <circle cx="50" cy="50" r="30" fill="currentColor" opacity="0.3"/>
              <circle cx="30" cy="30" r="15" fill="currentColor" opacity="0.5"/>
              <circle cx="70" cy="30" r="15" fill="currentColor" opacity="0.5"/>
              <circle cx="30" cy="70" r="15" fill="currentColor" opacity="0.5"/>
              <circle cx="70" cy="70" r="15" fill="currentColor" opacity="0.5"/>
            </svg>
          </div>
          <div className="absolute bottom-20 right-10 w-40 h-40 opacity-10 animate-pulse" style={{animationDelay: '1s'}}>
            <svg viewBox="0 0 100 100" className="w-full h-full text-green-600">
              <circle cx="50" cy="50" r="30" fill="currentColor" opacity="0.3"/>
              <circle cx="35" cy="35" r="12" fill="currentColor" opacity="0.5"/>
              <circle cx="65" cy="35" r="12" fill="currentColor" opacity="0.5"/>
              <circle cx="50" cy="65" r="12" fill="currentColor" opacity="0.5"/>
            </svg>
          </div>
        </div>

        {/* Main Content */}
        <div className="container mx-auto px-4 text-center relative z-10">
          <div className="mb-8">
            <h2 className="text-5xl md:text-7xl font-bold text-amber-900 mb-4 leading-tight">
              Visitor & Entry Management System
            </h2>
            <h3 className="text-3xl md:text-5xl font-semibold text-green-700 mb-6">
              Inspired by <span className="font-semibold text-amber-700">Governor Sir</span> and developed under the Hon'ble Vice-Chancellor of <span className="font-semibold text-green-700">Veer Madho Singh Bhandari Uttarakhand Technical University</span>
            </h3>
         
          </div>

          {/* CTA Button */}
          <Link
            href="/register/14"
            className="inline-block bg-gradient-to-r from-amber-600 to-orange-600 text-white px-8 md:px-12 py-3 md:py-4 rounded-full text-lg font-semibold hover:shadow-xl transition-all duration-300 hover:scale-105"
          >
            Register →
          </Link>
        </div>
      </header>
      {/* Vision Section with VC Image */}
      <section className="py-20 bg-white">
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
            {/* Left - Text */}
            <div>
              <h2 className="text-4xl font-bold text-amber-900 mb-6">Our Vision</h2>
              <p className="text-lg text-gray-700 mb-4 leading-relaxed">
                Inspired by the Governor's commitment to modernizing government operations, we have created a seamless visitor and entry management system that combines tradition with innovation.
              </p>
              <p className="text-lg text-gray-700 mb-4 leading-relaxed">
                Under the visionary leadership of the Hon'ble Vice-Chancellor of Veer Madho Singh Bhandari Uttarakhand Technical University, this system represents the future of secure and efficient administrative management.
              </p>
              <div className="flex items-center gap-4 mt-6">
                <div className="w-1 h-12 bg-gradient-to-b from-amber-600 to-green-600"></div>
                <p className="text-gray-600 italic">Building excellence in service delivery</p>
              </div>
            </div>

            {/* Right - Image */}
            <div className="relative">
              <div className="relative h-96 md:h-[400px] rounded-2xl overflow-hidden shadow-2xl">
                <Image
                  src="/images/vcwithgovernor.jpeg"
                  alt="Governor and Vice-Chancellor with flowers"
                  fill
                  className="object-cover"
                  priority
                />
              </div>
              <div className="absolute -bottom-6 -right-6 w-40 h-40 opacity-20 pointer-events-none">
                <svg viewBox="0 0 100 100" className="w-full h-full text-amber-600">
                  <path d="M50 10 L60 40 L90 40 L67 60 L77 90 L50 70 L23 90 L33 60 L10 40 L40 40 Z" fill="currentColor"/>
                </svg>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Key Features Section */}
      <section className="py-20 bg-gradient-to-r from-amber-50 to-green-50">
        <div className="container mx-auto px-4">
          <h2 className="text-4xl font-bold text-center text-amber-900 mb-12">Key Features</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              {
                title: "QR Code Verification",
                desc: "Quick and secure visitor verification with advanced QR technology"
              },
              {
                title: "Group Management",
                desc: "Efficient handling of group registrations and entries"
              },
              {
                title: "Real-time Analytics",
                desc: "Live monitoring and comprehensive visitor statistics"
              }
            ].map((feature, idx) => (
              <div key={idx} className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-shadow">
                <div className="w-12 h-12 bg-gradient-to-br from-amber-500 to-orange-500 rounded-full mb-4"></div>
                <h3 className="text-xl font-semibold text-amber-900 mb-3">{feature.title}</h3>
                <p className="text-gray-600">{feature.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
      <footer className="bg-gradient-to-r from-amber-800 to-orange-800 text-white py-12">
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
            {/* <div className="flex items-center gap-3">
              <Image src="/images/emblem_white.svg" alt="Logo" width={40} height={40} className="w-10 md:w-12" />
              <div>
                <p className="text-sm font-medium">राजभवन उत्तराखंड</p>
                <h1 className="text-lg font-bold">RAJ BHAWAN</h1>
              </div>
            </div> */}
            <div className="text-center">
              <p className="text-amber-100 text-sm">Inspired by Governor Sir</p>
              <p className="text-amber-100 text-sm">Developed under Hon'ble Vice-Chancellor</p>
              <p className="text-amber-100 text-sm">VMSBUTU</p>
            </div>
            <div className="text-center">
              <p className="text-sm text-amber-100">&copy; 2025 All rights reserved</p>
              <Link href="https://github.com/adityakumar-dev" className="text-amber-100 hover:text-white text-sm">Code by adityakumar-dev</Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}

