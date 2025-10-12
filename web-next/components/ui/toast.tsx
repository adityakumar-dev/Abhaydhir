import { useState, useEffect } from 'react';
import { X } from 'lucide-react';

interface ToastProps {
  message: string;
  type: 'success' | 'error';
  onClose: () => void;
  duration?: number;
}

export function Toast({ message, type, onClose, duration = 5000 }: ToastProps) {
  useEffect(() => {
    const timer = setTimeout(() => {
      onClose();
    }, duration);

    return () => clearTimeout(timer);
  }, [duration, onClose]);

  const bgColor = type === 'success' ? 'bg-green-500' : 'bg-red-500';

  return (
    <div className={`fixed top-4 right-4 z-50 flex items-center ${bgColor} text-white px-4 py-2 rounded-lg shadow-lg min-w-[300px]`}>
      <p className="flex-1">{message}</p>
      <button onClick={onClose} className="ml-4 hover:opacity-75">
        <X size={18} />
      </button>
    </div>
  );
} 