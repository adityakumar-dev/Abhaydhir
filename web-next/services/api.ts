import { Console } from "console";
import { METHODS } from "http";
import { useState } from "react";
import axios from 'axios';
import { redirect } from "next/dist/server/api-utils";
export const API_BASE_URL =  process.env.NEXT_PUBLIC_API_URL!;
// export const API_BASE_URL = 'https://api.vmsbutu.it.com' --- IGNORE ---
export const url = API_BASE_URL;
export interface RegisterData {
  name: string
  email: string
  userType: 'individual' | 'group'
  photo: File
  id_type: string,
  id : string,
  group_name: string,
  count : string,
}
interface CreateAppUser {
  admin_name: string,
  admin_password: string,
  user_name: string,
  user_password: string,
  user_email: string,
  unique_id_type: string,
  unique_id: string,
  profile_picture: File,
}
interface RegisterGroupData {
  name: string;

  group_size: number;
}
// export interface CreateAppUser extends RegisterData{
export const api = {
  latest_visitor_card: "",
  
  // Generate full URL for visitor card (for preview/download)
  getVisitorCardUrl: (visitorCardPath: string) => {
    if (!visitorCardPath) return null;
    // If it already has http://, return as is
    if (visitorCardPath.startsWith('http')) return visitorCardPath;
    // Otherwise, prepend API_BASE_URL
    // visitorCardPath format: /tourists/visitor-card/{jwt_token}
    return `${API_BASE_URL}${visitorCardPath}`;
  },
  
  // Get download URL for visitor card
  getVisitorCardDownloadUrl: (visitorCardPath: string) => {
    if (!visitorCardPath) return null;
    // Convert preview URL to download URL
    // /tourists/visitor-card/{token} -> /tourists/download-visitor-card/{token}
    const downloadPath = visitorCardPath.replace('/visitor-card/', '/download-visitor-card/');
    return `${API_BASE_URL}${downloadPath}`;
  },
  
  // Legacy method (keeping for backward compatibility)
  base: (card: string) => `${API_BASE_URL}/users/download-visitor-card/?card_path=${encodeURIComponent(card)}`,
  async createAppUser(data: CreateAppUser) {
    try {
      const formData = new FormData()
      formData.append('admin_name', data.admin_name)
      formData.append('admin_password', data.admin_password)
      formData.append('user_name', data.user_name)
      formData.append('user_password', data.user_password)
      formData.append('user_email', data.user_email)
      formData.append('unique_id_type', data.unique_id_type)
      formData.append('unique_id', data.unique_id)
      formData.append('profile_picture', data.profile_picture)

      console.log('Sending request to:', `${API_BASE_URL}/app_users/create`)
      console.log('Request data:', Object.fromEntries(formData.entries()))

      const response = await fetch(`${API_BASE_URL}/app_users/create`, { 
        method: 'POST', 
        body: formData,
        headers: {
          'Accept': 'application/json',
      
        }
      })

      console.log('Response status:', response.status)
      const responseText = await response.text()
      console.log('Response body:', responseText)
      console.log("Respnse json : ", JSON.parse(responseText))

      if (response.ok) {
        const responseResult = JSON.parse(responseText)
        if (responseResult['status']) {
          return true
        } else {
          throw new Error(responseResult['message'] || 'Unknown error occurred')
        }
      } else {
        console.error('Server returned error status:', response.status)
        return false
      }
    } catch (error) {
      console.error('Error in createAppUser:', error)
      return false
    }
  },
  async registerTourist(data: {
    name: string;
    email: string;
    unique_id_type: string;
    unique_id: string;
    is_group: boolean;
    group_count: number;
    registered_event_id: number;
    photo: File;
  }) {
    const formData = new FormData();
    formData.append("name", data.name);
    formData.append("email", data.email);
    formData.append("unique_id_type", data.unique_id_type);
    formData.append("unique_id", data.unique_id);
    formData.append("is_group", String(data.is_group));
    formData.append("group_count", String(data.group_count));
    formData.append("registered_event_id", String(data.registered_event_id));
    formData.append("image", data.photo);
    try {
      const response = await fetch(`${API_BASE_URL}/tourists/register`, {
        method: 'POST',
        body: formData,
        // headers: {
        //   'Accept': 'application/json',
        // },
      });
      if (!response.ok) {
        const error = await response.json().catch(() => null);
        throw new Error(error?.detail || error?.message || 'Registration failed');
      }
      return await response.json();
    } catch (error) {
      console.error('Tourist registration error:', error);
      throw error;
    }
  },

  async checkEventExists(event_id: number) {
    try {
      console.log("Checking event ID in API:", event_id);
      console.log("Event ID payload:", { event_id });
      console.log("API_BASE_URL:", API_BASE_URL);
      const response = await fetch(`${API_BASE_URL}/event/check/${event_id}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
        },
      });
      if (!response.ok) {
        return false;
      }
      const result = await response.json();
      console.log('Event check result:', result);
      return result.event.is_active === true;
    } catch (error) {
      console.error('Event check error:', error);
      return false;
    }
  },
  
  }