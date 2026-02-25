# services/camera_manager.py

from fastapi import WebSocket
from typing import Dict

class CameraManager:
    def __init__(self):
        self.connections: Dict[str, WebSocket] = {}
        self.latest_frames = {}

    async def register(self, camera_id: str, ws: WebSocket):
        self.connections[camera_id] = ws

    def disconnect(self, camera_id: str):
        if camera_id in self.connections:
            del self.connections[camera_id]

    def get(self, camera_id: str):
        return self.connections.get(camera_id)

camera_manager = CameraManager()