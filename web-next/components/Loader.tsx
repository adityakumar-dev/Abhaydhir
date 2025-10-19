import React from 'react';
import { ClipLoader } from 'react-spinners';

const Loader = () => {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white rounded-lg p-8 shadow-xl flex flex-col items-center">
        <ClipLoader
          color="#3B82F6"
          size={50}
          aria-label="Loading Spinner"
          data-testid="loader"
        />
        <p className="mt-4 text-lg font-semibold text-gray-700">Loading...</p>
        <p className="mt-2 text-sm text-gray-500">Please wait while we prepare your experience</p>
      </div>
    </div>
  );
};

export default Loader; 