import type { Metadata } from 'next'
import './globals.css'
import { RouteLoadingOverlay } from '@/components/RouteLoadingOverlay'

export const metadata: Metadata = {
  title: 'E-Management',
  // description: 'Created with v0',
  // generator: 'v0.dev',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body>
        <RouteLoadingOverlay />
        {children}
      </body>
    </html>
  )
}
