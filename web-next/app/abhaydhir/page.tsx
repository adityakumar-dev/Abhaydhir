"use client"

import { useState } from "react"
import { Download, Shield, Smartphone, AlertTriangle, CheckCircle2, ArrowRight } from "lucide-react"
import Image from "next/image"
import Link from "next/link"
import Navbar from "../components/Navbar"
import { LoadingBar } from "../components/loading-bar"

export default function InstallationGuidePage() {
  const [showWarning, setShowWarning] = useState(true);

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
              ABHAYDHIR APP
            </h1>
            <h2 className="text-2xl md:text-6xl mb-6 text-gray-700 animate-fade-in-down leading-tight">
              Download & Installation Guide
            </h2>
            <p className="text-lg md:text-xl mb-8 text-gray-600 animate-fade-in-up max-w-3xl mx-auto">
            Abhaydhir is a mobile application that allows Security Guards to manage visitors entry and exit.
            </p>
            <a
              href="/app/app-release.apk"
              download
              className="inline-flex items-center px-8 md:px-12 py-3 md:py-4 bg-gradient-to-r from-amber-600 to-orange-600 text-white rounded-full text-lg md:text-xl hover:from-amber-700 hover:to-orange-700 transition duration-300 shadow-lg hover:shadow-xl hover:scale-105 transform"
            >
              <Download className="w-6 h-6 mr-2" />
              Download APK
            </a>
          </div>
        </div>
      </header>

      {showWarning && (
        <div className="bg-yellow-50 border-b border-yellow-200">
          <div className="container mx-auto px-4 py-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <AlertTriangle className="h-5 w-5 text-yellow-600" />
                <p className="text-sm text-yellow-800">
                  This app is not available on the Play Store. Installation requires enabling "Install from Unknown Sources".
                </p>
              </div>
              <button 
                onClick={() => setShowWarning(false)}
                className="text-yellow-600 hover:text-yellow-800"
              >
                ×
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Security & Play Store Warning */}
      <section className="py-8">
        <div className="container mx-auto px-4">
          <div className="max-w-3xl mx-auto bg-yellow-100 border-l-4 border-yellow-400 p-6 rounded-lg flex items-start space-x-4">
            <Shield className="w-8 h-8 text-yellow-500 mt-1" />
            <div>
              <h4 className="text-lg font-semibold text-yellow-800 mb-1">Important Security Notice</h4>
              <p className="text-yellow-700">
                This app is <b>not available on the Google Play Store</b>. Because of this, Android will warn you before installation. 
                Please ensure you trust the source before proceeding. This APK is the official release for the Spring Festival 2025, built with Flutter.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Download Button */}
      <section className="py-4">
        <div className="container mx-auto px-4 text-center">
          <a
            href="/app/app-release.apk"
            download
            className="inline-flex items-center px-6 py-3 bg-green-600 text-white rounded-lg shadow-lg hover:bg-green-700 transition-colors font-semibold text-lg gap-2"
          >
            <Download className="w-6 h-6" />
            Download APK
          </a>
          <p className="mt-2 text-sm text-gray-500">(File: app-release.apk, Flutter Android App)</p>
        </div>
      </section>

      {/* Step-by-Step Installation Guide */}
      <section className="py-8">
        <div className="container mx-auto px-4">
          <div className="max-w-2xl mx-auto bg-white rounded-lg shadow p-6">
            <h3 className="text-xl font-bold text-gray-800 mb-4 text-center">How to Install the App</h3>
            <ol className="space-y-6">
              <li className="flex items-start gap-4">
                <Smartphone className="w-7 h-7 text-blue-600 mt-1" />
                <div>
                  <span className="font-semibold text-gray-900">Step 1: Download the APK</span>
                  <p className="text-gray-700">Tap the <b>Download APK</b> button above to download the app to your device.</p>
                </div>
              </li>
              <li className="flex items-start gap-4">
                <Shield className="w-7 h-7 text-yellow-600 mt-1" />
                <div>
                  <span className="font-semibold text-gray-900">Step 2: Allow Unknown Sources</span>
                  <p className="text-gray-700">Android will warn you about installing apps from outside the Play Store. Go to <b>Settings &gt; Security</b> and enable <b>Install from Unknown Sources</b> for your browser or file manager.</p>
                </div>
              </li>
              <li className="flex items-start gap-4">
                <Download className="w-7 h-7 text-green-600 mt-1" />
                <div>
                  <span className="font-semibold text-gray-900">Step 3: Install the App</span>
                  <p className="text-gray-700">Open the downloaded <b>app-release.apk</b> file and follow the prompts to install the app on your device.</p>
                </div>
              </li>
              <li className="flex items-start gap-4">
                <CheckCircle2 className="w-7 h-7 text-green-700 mt-1" />
                <div>
                  <span className="font-semibold text-gray-900">Step 4: Open & Enjoy</span>
                  <p className="text-gray-700">Once installed, open the app and enjoy the Spring Festival 2025 experience!</p>
                </div>
              </li>
            </ol>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section className="py-12">
        <div className="container mx-auto px-4">
          <div className="max-w-4xl mx-auto">
            <h2 className="text-2xl font-bold text-gray-800 mb-6 text-center">Frequently Asked Questions</h2>
            <div className="space-y-6">
              <div className="bg-white rounded-lg shadow p-5">
                <h3 className="font-semibold text-gray-900 mb-2 flex items-center"><Smartphone className="w-5 h-5 mr-2 text-blue-600" />Is this app safe to install?</h3>
                <p className="text-gray-700">Yes, this APK is the official release from the Spring Festival 2025 organizers. Always download from the official website or trusted sources.</p>
              </div>
              <div className="bg-white rounded-lg shadow p-5">
                <h3 className="font-semibold text-gray-900 mb-2 flex items-center"><AlertTriangle className="w-5 h-5 mr-2 text-yellow-600" />Why do I see a warning from Android?</h3>
                <p className="text-gray-700">Android warns users when installing apps from outside the Play Store to protect against malware. As long as you download from our official site, you can safely proceed.</p>
              </div>
              <div className="bg-white rounded-lg shadow p-5">
                <h3 className="font-semibold text-gray-900 mb-2 flex items-center"><CheckCircle2 className="w-5 h-5 mr-2 text-green-600" />Will the app be available on the Play Store?</h3>
                <p className="text-gray-700">We are working towards a Play Store release. For now, please use the APK provided here for the latest features and updates.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Back to Home or Other Pages */}
      <section className="py-8">
        <div className="container mx-auto px-4 text-center">
          <Link href="/" className="inline-flex items-center px-5 py-3 bg-gradient-to-r from-amber-600 to-orange-600 text-white rounded-lg hover:from-amber-700 hover:to-orange-700 transition-colors font-semibold hover:scale-105 transform">
            <ArrowRight className="w-5 h-5 mr-2" />
            Back to Home
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gradient-to-r from-amber-800 to-orange-800 text-white py-12">
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-center">
            {/* Logo Section */}
            <div className="flex items-center gap-3 brightness-0 invert">
              <Image src="/images/emblem_white.svg" alt="Government Logo" width={40} height={40} className="w-8 md:w-12" />
              <div className="flex flex-col">
                <p className="text-sm md:text-lg text-white">राजभवन उत्तराखंड</p>
                <h1 className="text-base md:text-xl text-white font-bold">RAJBHAWAN UTTARAKHAND</h1>
              </div>
            </div>

            {/* Attribution Section */}
            <div className="text-center">
              <p className="text-sm md:text-base text-white/90 mb-1">
                Inspired by Governor Sir and developed under
              </p>
              <p className="text-sm md:text-base text-white font-semibold">
                Hon'ble Vice Chancellor of VMSBVTU
              </p>
            </div>

            {/* Copyright Section */}
            <div className="text-center md:text-right">
              <p className="text-sm text-white/80">&copy; 2025 All rights reserved.</p>
              <a
                href="https://github.com/adityakumar-dev/Abhaydhir"
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-white/80 hover:text-white transition-colors duration-300 inline-flex items-center gap-1"
              >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
                View on GitHub
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
