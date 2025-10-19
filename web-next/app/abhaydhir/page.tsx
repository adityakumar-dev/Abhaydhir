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
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
      <LoadingBar />
      <header className="w-full relative bg-cover bg-center h-screen">
        <div
          className="absolute inset-0 w-full h-full transition-opacity duration-1000 ease-in-out"
          style={{
            backgroundImage: `linear-gradient(rgba(0, 0, 0, 0.5), rgba(0, 0, 0, 0.5)), url('/images/spring_festival/image4.jpg')`,
            backgroundSize: 'cover',
            backgroundPosition: 'center',
          }}
        />
        
        <Navbar />

        {/* Hero Content */}
        <div className="flex flex-col items-center justify-center h-[calc(100vh-80px)] px-4">
          <div className="container mx-auto px-4 text-center relative z-10">
            <h1 className="text-4xl md:text-7xl font-bold mb-4 text-white animate-fade-in-down leading-tight">
              ABHAYDHIR APP
            </h1>
            <h2 className="text-2xl md:text-6xl mb-6 text-white animate-fade-in-down leading-tight">
              Download & Installation Guide
            </h2>
            <p className="text-lg md:text-xl mb-8 text-gray-200 animate-fade-in-up max-w-3xl mx-auto">
            Abhaydhir is a mobile application that allows Security Guards to manage visitors entry and exit.
            </p>
            <a
              href="/app/app-release.apk"
              download
              className="inline-flex items-center px-8 md:px-12 py-3 md:py-4 bg-yellow-600 text-white rounded-full text-lg md:text-xl hover:bg-yellow-500 transition duration-300 shadow-lg hover:shadow-xl"
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
          <Link href="/" className="inline-flex items-center px-5 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-semibold">
            <ArrowRight className="w-5 h-5 mr-2" />
            Back to Home
          </Link>
        </div>
      </section>
    </div>
  );
}
