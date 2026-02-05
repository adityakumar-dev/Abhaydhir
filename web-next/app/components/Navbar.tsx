"use client"

import Link from "next/link"
import Image from "next/image"
import { useState } from "react"
import { useRouter } from "next/navigation";

export default function Navbar() {
  const router = useRouter();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <nav className="bg-black/30 backdrop-blur-md shadow-lg sticky top-0 z-50">
      <div className="container mx-auto px-4 py-3">
        <div className="flex items-center justify-between">
          {/* Logo - Made more compact for mobile */}
          <div className="flex items-center space-x-2 " onClick={() => router.push('/')}>
            <Image src="/images/emblem_white.svg" alt="Logo" width={40} height={40} 
              className="w-8 h-8 md:w-10 md:h-10 brightness-0 invert" />
            <div className="flex flex-col">
              <p className="text-xs md:text-sm text-white">राजभवन उत्तराखंड</p>
              <h1 className="text-sm md:text-lg text-white font-bold">RAJBHAWAN UTTARAKHAND</h1>
              <p className="text-[10px] md:text-xs text-yellow-400">Visitor & Entry Management System</p>
            </div>
          </div>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center space-x-8">
            {/* <Link href="/about" className="text-white hover:text-yellow-400 transition-colors">About</Link> */}
            <Link href="/vasontutsav2025" className="text-white hover:text-yellow-400 transition-colors">Past Events</Link>
            <Link href="/register/14" className="text-white hover:text-yellow-400 transition-colors">Registration</Link>
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

        {/* Mobile Navigation - Slide down menu */}
        {mobileMenuOpen && (
          <div className="md:hidden mt-4 pb-4 border-t border-white/20">
            <div className="flex flex-col space-y-3 pt-3">
              <Link 
                href="/about" 
                className="text-white hover:text-yellow-400 transition-colors px-2 py-2 rounded-lg hover:bg-white/10"
                onClick={() => setMobileMenuOpen(false)}
              >
                About
              </Link>
              <Link 
                href="/features" 
                className="text-white hover:text-yellow-400 transition-colors px-2 py-2 rounded-lg hover:bg-white/10"
                onClick={() => setMobileMenuOpen(false)}
              >
                Features
              </Link>
              <Link 
                href="/vasontutsav2025" 
                className="text-white hover:text-yellow-400 transition-colors px-2 py-2 rounded-lg hover:bg-white/10"
                onClick={() => setMobileMenuOpen(false)}
              >
                Past Events
              </Link>
              <Link 
                href="/register" 
                className="text-white hover:text-yellow-400 transition-colors px-2 py-2 rounded-lg hover:bg-white/10"
                onClick={() => setMobileMenuOpen(false)}
              >
                Registration
              </Link>
              <Link 
                href="/abhaydhir" 
                className="text-white hover:text-yellow-400 transition-colors px-2 py-2 rounded-lg hover:bg-white/10"
                onClick={() => setMobileMenuOpen(false)}
              >
                Abhaydhir App
              </Link>
            </div>
          </div>
        )}
      </div>
    </nav>
  )
} 