"use client"

import Link from "next/link"
import Image from "next/image"
import { CheckCircle, Shield, QrCode, Users, Mail, Camera, Database, ChartBar } from "lucide-react"
import Navbar from "../components/Navbar"
import { LoadingBar } from "../components/loading-bar"

export default function FeaturesPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 via-white to-green-50">
      <LoadingBar />
      <header className="w-full relative h-screen overflow-hidden">
        {/* Floral Background Elements */}
        <div className="absolute inset-0 opacity-10">
          <svg className="absolute top-20 left-10 w-32 h-32 text-amber-200 animate-pulse" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
          </svg>
          <svg className="absolute top-40 right-20 w-24 h-24 text-orange-200 animate-pulse" style={{animationDelay: '1s'}} viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
          </svg>
          <svg className="absolute bottom-32 left-20 w-28 h-28 text-green-200 animate-pulse" style={{animationDelay: '2s'}} viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
          </svg>
          <svg className="absolute bottom-20 right-10 w-20 h-20 text-amber-300 animate-pulse" style={{animationDelay: '0.5s'}} viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
          </svg>
        </div>
        
        <Navbar />

        {/* Hero Content */}
        <div className="flex flex-col items-center justify-center h-[calc(100vh-80px)] px-4 relative z-10">
          <div className="container mx-auto px-4 text-center">
            <h1 className="text-4xl md:text-7xl font-bold mb-4 text-gray-800 animate-fade-in-down leading-tight">
              ADVANCED FEATURES
            </h1>
            <h2 className="text-2xl md:text-6xl mb-6 text-gray-700 animate-fade-in-down leading-tight">
              Experience seamless event management
            </h2>
            <p className="text-lg md:text-xl mb-8 text-gray-600 animate-fade-in-up max-w-3xl mx-auto">
              Discover our cutting-edge technology solutions for efficient visitor management
            </p>
          </div>
        </div>
      </header>

      {/* How It Works Section */}
      <section className="py-20 bg-white">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center text-gray-800 mb-16">How It Works</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            {/* Register Card */}
            <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-blue-50 flex items-center justify-center">
                <Users className="w-10 h-10 text-blue-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Register</h3>
              <p className="text-gray-600 text-center">Register with basic details</p>
            </div>

            {/* Response Card */}
            <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-green-50 flex items-center justify-center">
                <Mail className="w-10 h-10 text-green-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Response</h3>
              <p className="text-gray-600 text-center">Receive instant confirmation with QR code and email response</p>
            </div>

            {/* Verify Card */}
            <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-yellow-50 flex items-center justify-center">
                <Shield className="w-10 h-10 text-yellow-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Verify</h3>
              <p className="text-gray-600 text-center">Scan QR code and complete verification</p>
            </div>

            {/* Attend Card */}
            <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-20 h-20 mx-auto mb-6 rounded-full bg-purple-50 flex items-center justify-center">
                <CheckCircle className="w-10 h-10 text-purple-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Attend</h3>
              <p className="text-gray-600 text-center">Enjoy seamless entry and exit with our advanced security system</p>
            </div>
          </div>
        </div>
      </section>

      {/* Key Features Section */}
      <section className="py-20 bg-gray-50">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center text-gray-800 mb-16">Key Features</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {/* QR Code Integration */}
            <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-blue-50 flex items-center justify-center">
                <QrCode className="w-8 h-8 text-blue-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">QR Code Integration</h3>
              <p className="text-gray-600 text-center">Unique QR codes for quick and secure event check-ins with real-time validation</p>
            </div>

            {/* Email Response */}
            <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-green-50 flex items-center justify-center">
                <Mail className="w-8 h-8 text-green-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Email Response</h3>
              <p className="text-gray-600 text-center">Instant email confirmation with event details and QR code attachment</p>
            </div>

            {/* Facial Recognition */}
            {/* <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-yellow-50 flex items-center justify-center">
                <Camera className="w-8 h-8 text-yellow-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Facial Recognition</h3>
              <p className="text-gray-600 text-center">Advanced AI-powered facial recognition for enhanced security and quick verification</p>
            </div> */}

            {/* Group Management */}
            {/* <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-purple-50 flex items-center justify-center">
                <Users className="w-8 h-8 text-purple-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Group Management</h3>
              <p className="text-gray-600 text-center">Efficient handling of institution groups with dedicated admin controls</p>
            </div> */}

            {/* Aadhaar Integration */}
            {/* <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-red-50 flex items-center justify-center">
                <Database className="w-8 h-8 text-red-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Aadhaar Integration</h3>
              <p className="text-gray-600 text-center">Secure Aadhaar verification for enhanced identity validation</p>
            </div> */}

            {/* Real-time Analytics */}
            <div className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-all duration-300 border border-gray-100 hover:-translate-y-1">
              <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-indigo-50 flex items-center justify-center">
                <ChartBar className="w-8 h-8 text-indigo-600" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3 text-center">Real-time Analytics</h3>
              <p className="text-gray-600 text-center">Live insights into event attendance, flow, and security metrics</p>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section className="py-20 bg-white">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center text-gray-800 mb-16">Frequently Asked Questions</h2>
          <div className="max-w-4xl mx-auto space-y-6">
            {/* Registration FAQs */}
            <div className="bg-gray-50 rounded-xl p-6 hover:shadow-lg transition-all duration-300">
              <h3 className="text-xl font-semibold text-gray-800 mb-3">How can I register for the event?</h3>
              <p className="text-gray-600">You can register by clicking the "Register Now" button. The process is simple and takes only a few minutes to complete.</p>
            </div>

            <div className="bg-gray-50 rounded-xl p-6 hover:shadow-lg transition-all duration-300">
              <h3 className="text-xl font-semibold text-gray-800 mb-3">What documents do I need for verification?</h3>
              <p className="text-gray-600">A valid Government-issued ID (Aadhaar, Voter ID, Driving License, Passport) or institution ID card is required for verification.</p>
            </div>

            {/* <div className="bg-gray-50 rounded-xl p-6 hover:shadow-lg transition-all duration-300">
              <h3 className="text-xl font-semibold text-gray-800 mb-3">How does the facial recognition system work?</h3>
              <p className="text-gray-600">Our AI-powered system captures your facial features and matches them with your registered photo for secure verification.</p>
            </div> */}

            <div className="bg-gray-50 rounded-xl p-6 hover:shadow-lg transition-all duration-300">
              <h3 className="text-xl font-semibold text-gray-800 mb-3">Can I register a group of people?</h3>
              <p className="text-gray-600">Yes, institutional groups can be registered by a designated group leader who will manage the group's registration and entry.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Call to Action */}
      <section className="py-20 bg-gradient-to-r from-amber-700 to-orange-700 text-white">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold mb-6">Ready to Experience Our Features?</h2>
          <p className="text-xl mb-8">Register now and be part of the Spring Festival 2025</p>
          <Link
            href="/register"
            className="bg-white text-amber-700 px-8 py-3 rounded-full text-lg font-semibold hover:bg-gray-100 transition duration-300 inline-block hover:scale-105 transform"
          >
            Register Now
          </Link>
        </div>
      </section>

      {/* Footer */}
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
      </footer> </div>
  )
} 