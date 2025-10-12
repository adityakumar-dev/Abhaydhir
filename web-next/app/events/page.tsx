"use client"

import Image from "next/image"
import Link from "next/link"
import { Calendar, MapPin, Users, Clock } from "lucide-react"

export default function EventsPage() {
  const upcomingEvents = [
    {
      id: 1,
      title: "Spring Festival 2025",
      date: "March 15, 2025",
      time: "10:00 AM - 6:00 PM",
      location: "Raj Bhawan, Dehradun",
      image: "/images/spring_festival/image1.jpg",
      description: "Join us for the annual Spring Festival featuring cultural performances, exhibitions, and more.",
      expectedAttendees: "1000+"
    },
    {
      id: 2,
      title: "Republic Day Celebration",
      date: "January 26, 2025",
      time: "8:00 AM - 12:00 PM",
      location: "Raj Bhawan, Dehradun",
      image: "/images/spring_festival/image2.jpg",
      description: "Celebrate Republic Day with flag hoisting ceremony and cultural programs.",
      expectedAttendees: "500+"
    }
  ]

  const pastEvents = [
    {
      id: 3,
      title: "Spring Festival 2024",
      date: "March 15, 2024",
      location: "Raj Bhawan, Dehradun",
      image: "/images/spring_festival/image3.jpg",
      description: "A successful celebration of spring with cultural performances and exhibitions.",
      attendees: "1200+"
    },
    {
      id: 4,
      title: "Independence Day 2024",
      date: "August 15, 2024",
      location: "Raj Bhawan, Dehradun",
      image: "/images/spring_festival/image4.jpg",
      description: "Commemoration of India's independence with cultural programs and flag hoisting.",
      attendees: "800+"
    }
  ]

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
      {/* Hero Section */}
      <header className="relative bg-cover bg-center h-[40vh]" style={{ backgroundImage: 'linear-gradient(rgba(0, 0, 0, 0.7), rgba(0, 0, 0, 0.7)), url("/images/spring_festival/image2.jpg")' }}>
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="text-center text-white">
            <h1 className="text-4xl md:text-5xl font-bold mb-4">Events</h1>
            <p className="text-xl">Discover upcoming and past events at Raj Bhawan</p>
          </div>
        </div>
      </header>

      {/* Upcoming Events Section */}
      <section className="py-16">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-gray-800 text-center mb-12">Upcoming Events</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {upcomingEvents.map((event) => (
              <div key={event.id} className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow">
                <div className="relative h-48">
                  <Image
                    src={event.image}
                    alt={event.title}
                    fill
                    className="object-cover"
                  />
                </div>
                <div className="p-6">
                  <h3 className="text-2xl font-bold text-gray-800 mb-4">{event.title}</h3>
                  <div className="space-y-3 mb-4">
                    <div className="flex items-center text-gray-600">
                      <Calendar className="w-5 h-5 mr-2" />
                      <span>{event.date}</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <Clock className="w-5 h-5 mr-2" />
                      <span>{event.time}</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <MapPin className="w-5 h-5 mr-2" />
                      <span>{event.location}</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <Users className="w-5 h-5 mr-2" />
                      <span>Expected Attendees: {event.expectedAttendees}</span>
                    </div>
                  </div>
                  <p className="text-gray-600 mb-6">{event.description}</p>
                  <Link
                    href="/register"
                    className="inline-block bg-yellow-600 text-white py-2 px-6 rounded-lg hover:bg-yellow-500 transition duration-300"
                  >
                    Register Now
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Past Events Section */}
      <section className="py-16 bg-white">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-gray-800 text-center mb-12">Past Events</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {pastEvents.map((event) => (
              <div key={event.id} className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow">
                <div className="relative h-48">
                  <Image
                    src={event.image}
                    alt={event.title}
                    fill
                    className="object-cover"
                  />
                </div>
                <div className="p-6">
                  <h3 className="text-2xl font-bold text-gray-800 mb-4">{event.title}</h3>
                  <div className="space-y-3 mb-4">
                    <div className="flex items-center text-gray-600">
                      <Calendar className="w-5 h-5 mr-2" />
                      <span>{event.date}</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <MapPin className="w-5 h-5 mr-2" />
                      <span>{event.location}</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <Users className="w-5 h-5 mr-2" />
                      <span>Attendees: {event.attendees}</span>
                    </div>
                  </div>
                  <p className="text-gray-600">{event.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 bg-blue-600">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold text-white mb-6">Want to Host an Event?</h2>
          <p className="text-xl text-blue-100 mb-8">Contact us to learn more about hosting your event at Raj Bhawan.</p>
          <Link href="/contact" className="inline-block bg-yellow-600 text-white py-3 px-8 rounded-lg hover:bg-yellow-500 transition duration-300">
            Contact Us
          </Link>
        </div>
      </section>

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