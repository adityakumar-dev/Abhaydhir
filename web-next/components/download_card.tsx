import React, { useState } from 'react';
import { api } from '@/services/api';

interface DownloadCardProps {
  cardPath: string;
  isOpen: boolean;
  onClose: () => void;
}

const DownloadCardPopup: React.FC<DownloadCardProps> = ({ cardPath, isOpen, onClose }) => {
  const [imageError, setImageError] = useState(false);
  const [imageLoaded, setImageLoaded] = useState(false);

  if (!isOpen) return null;

  // cardPath is the preview URL: http://localhost:8000/tourists/visitor-card/{jwt_token}
  const previewUrl = cardPath;
  // Get download URL: http://localhost:8000/tourists/download-visitor-card/{jwt_token}
  const downloadUrl = cardPath.replace('/visitor-card/', '/download-visitor-card/');

  const handleDownload = () => {
    const link = document.createElement('a');
    link.href = downloadUrl;
    link.target = '_blank';
    link.download = 'visitor_card.png';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleImageError = () => {
    console.error('Failed to load image:', previewUrl);
    setImageError(true);
  };

  const handleImageLoad = () => {
    console.log('Image loaded successfully:', previewUrl);
    setImageLoaded(true);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
      <div className="bg-white rounded-lg shadow-lg p-6 max-w-sm w-full text-center">
        <h2 className="text-lg font-semibold mb-4">Download Your Registration Card</h2>
        
        {/* Show loading state */}
        {!imageLoaded && !imageError && (
          <div className="mx-auto mb-4 h-48 flex items-center justify-center bg-gray-100 rounded border">
            <p className="text-gray-500">Loading preview...</p>
          </div>
        )}
        
        {/* Show error state */}
        {imageError && (
          <div className="mx-auto mb-4 p-4 bg-red-50 rounded border border-red-200">
            <p className="text-red-600 text-sm">Preview not available</p>
            <p className="text-gray-500 text-xs mt-1">You can still download the card</p>
          </div>
        )}
        
        {/* Show image */}
        <img
          src={previewUrl}
          alt="Visitor Card Preview"
          className={`mx-auto mb-4 max-h-48 rounded border ${imageLoaded ? 'block' : 'hidden'}`}
          onError={handleImageError}
          onLoad={handleImageLoad}
        />
        
        <div className="flex justify-center gap-4 mt-4">
          <button
            onClick={handleDownload}
            className="bg-yellow-600 text-white px-4 py-2 rounded hover:bg-yellow-700 transition-colors"
          >
            Download Card
          </button>
          <button
            onClick={onClose}
            className="bg-gray-200 text-gray-700 px-4 py-2 rounded hover:bg-gray-300 transition-colors"
          >
            Close
          </button>
        </div>
        
        {/* Debug info in development */}
        {process.env.NODE_ENV === 'development' && (
          <div className="mt-4 p-2 bg-gray-100 rounded text-xs text-left overflow-auto max-h-20">
            <p className="text-gray-600">Preview: {previewUrl}</p>
            <p className="text-gray-600">Download: {downloadUrl}</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default DownloadCardPopup;
