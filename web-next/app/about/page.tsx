// "use client"

// import Image from "next/image"
// import Link from "next/link"
// import { ShieldCheck, Users, Calendar, CheckCircle } from "lucide-react"
// import Navbar from "../components/Navbar"
// import { LoadingBar } from "../components/loading-bar"

// export default function AboutPage() {
//   return (
//     <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
//       <LoadingBar />
//       <header className="w-full relative bg-cover bg-center h-screen">
//         <div
//           className="absolute inset-0 w-full h-full transition-opacity duration-1000 ease-in-out"
//           style={{
//             backgroundImage: `linear-gradient(rgba(0, 0, 0, 0.5), rgba(0, 0, 0, 0.5)), url('/images/spring_festival/image1.jpg')`,
//             backgroundSize: 'cover',
//             backgroundPosition: 'center',
//           }}
//         />
        
//         <Navbar />

//         {/* Hero Content */}
//         <div className="flex flex-col items-center justify-center h-[calc(100vh-80px)] px-4">
//           <div className="container mx-auto px-4 text-center relative z-10">
//             <h1 className="text-4xl md:text-7xl font-bold mb-4 text-white animate-fade-in-down leading-tight">
//               ABOUT US
//             </h1>
//             <h2 className="text-2xl md:text-6xl mb-6 text-white animate-fade-in-down leading-tight">
//               Learn about our Visitor & Entry Management System
//             </h2>
//             <p className="text-lg md:text-xl mb-8 text-gray-200 animate-fade-in-up max-w-3xl mx-auto">
//               Discover how we're revolutionizing visitor management at Raj Bhawan Uttarakhand
//             </p>
//           </div>
//         </div>
//       </header>

//       {/* Mission Section */}
//       <section className="py-16">
//         <div className="container mx-auto px-4">
//           <div className="max-w-3xl mx-auto text-center">
//             <h2 className="text-3xl font-bold text-gray-800 mb-6">Our Mission</h2>
//             <p className="text-lg text-gray-600 mb-8">
//               The Visitor & Entry Management System is designed to streamline and secure the process of managing visitors at Raj Bhawan, Uttarakhand. Our mission is to provide a seamless, efficient, and secure experience for both visitors and administrators.
//             </p>
//           </div>
//         </div>
//       </section>

//       {/* Key Features */}
//       <section className="py-16 bg-white">
//         <div className="container mx-auto px-4">
//           <h2 className="text-3xl font-bold text-gray-800 text-center mb-12">Key Features</h2>
//           <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
//             <div className="bg-white p-6 rounded-xl shadow-lg hover:shadow-xl transition-shadow">
//               <div className="bg-blue-50 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
//                 <ShieldCheck className="w-6 h-6 text-blue-600" />
//               </div>
//               <h3 className="text-xl font-semibold text-gray-800 mb-2">Advanced Security</h3>
//               <p className="text-gray-600">State-of-the-art facial recognition and QR code verification for enhanced security.</p>
//             </div>

//             <div className="bg-white p-6 rounded-xl shadow-lg hover:shadow-xl transition-shadow">
//               <div className="bg-green-50 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
//                 <Users className="w-6 h-6 text-green-600" />
//               </div>
//               <h3 className="text-xl font-semibold text-gray-800 mb-2">Group Management</h3>
//               <p className="text-gray-600">Efficient handling of group visits with streamlined registration and verification.</p>
//             </div>

//             <div className="bg-white p-6 rounded-xl shadow-lg hover:shadow-xl transition-shadow">
//               <div className="bg-yellow-50 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
//                 <Calendar className="w-6 h-6 text-yellow-600" />
//               </div>
//               <h3 className="text-xl font-semibold text-gray-800 mb-2">Event Management</h3>
//               <p className="text-gray-600">Comprehensive tools for managing special events and large gatherings.</p>
//             </div>

//             <div className="bg-white p-6 rounded-xl shadow-lg hover:shadow-xl transition-shadow">
//               <div className="bg-purple-50 p-3 rounded-full w-12 h-12 flex items-center justify-center mb-4">
//                 <CheckCircle className="w-6 h-6 text-purple-600" />
//               </div>
//               <h3 className="text-xl font-semibold text-gray-800 mb-2">Real-time Analytics</h3>
//               <p className="text-gray-600">Live monitoring and analytics for better decision-making and resource allocation.</p>
//             </div>
//           </div>
//         </div>
//       </section>

//       {/* Team Section */}
//       <section className="py-16">
//         <div className="container mx-auto px-4">
//           <h2 className="text-3xl font-bold text-gray-800 text-center mb-12">Our Team</h2>
//           <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
//             <div className="text-center">
//               <div className="bg-white p-6 rounded-xl shadow-lg">
//                 <h3 className="text-xl font-semibold text-gray-800 mb-2">Administration</h3>
//                 <p className="text-gray-600">Dedicated team managing visitor registrations and security protocols.</p>
//               </div>
//             </div>
//             <div className="text-center">
//               <div className="bg-white p-6 rounded-xl shadow-lg">
//                 <h3 className="text-xl font-semibold text-gray-800 mb-2">Technical Support</h3>
//                 <p className="text-gray-600">Expert team ensuring smooth operation of the management system.</p>
//               </div>
//             </div>
//             <div className="text-center">
//               <div className="bg-white p-6 rounded-xl shadow-lg">
//                 <h3 className="text-xl font-semibold text-gray-800 mb-2">Security Personnel</h3>
//                 <p className="text-gray-600">Trained professionals maintaining safety and security standards.</p>
//               </div>
//             </div>
//           </div>
//         </div>
//       </section>

//       {/* CTA Section */}
//       <section className="py-16 bg-blue-600">
//         <div className="container mx-auto px-4 text-center">
//           <h2 className="text-3xl font-bold text-white mb-6">Ready to Experience Our System?</h2>
//           <p className="text-xl text-blue-100 mb-8">Join us in creating a safer and more efficient visitor management experience.</p>
//           <Link href="/register" className="inline-block bg-yellow-600 text-white py-3 px-8 rounded-lg hover:bg-yellow-500 transition duration-300">
//             Register Now
//           </Link>
//         </div>
//       </section>

//       {/* Footer */}
//       <footer className="bg-gray-900 text-white py-8">
//         <div className="container mx-auto px-4">
//           <div className="flex flex-col md:flex-row justify-between items-center">
//             <div className="flex items-center gap-3 brightness-0 invert mb-4 md:mb-0">
//               <Image src="/images/emblem_white.svg" alt="Government Logo" width={40} height={40} className="w-8 md:w-12" />
//               <div className="flex flex-col">
//                 <p className="text-sm md:text-lg text-white">राजभवन उत्तराखंड</p>
//                 <h1 className="text-base md:text-xl text-white font-bold">RAJBHAWAN UTTARAKHAND</h1>
//                 <p className="text-xs text-yellow-400">Visitor & Entry Management System</p>
//               </div>
//             </div>
//             <div className="text-center md:text-right">
//               <p className="text-sm text-gray-400">&copy; 2025 All rights reserved.</p>
//               <p className="text-sm text-gray-400">Developed by Uttarakhand Technical University</p>
//             </div>
//           </div>
//         </div>
//       </footer>
//     </div>
//   )
// } 