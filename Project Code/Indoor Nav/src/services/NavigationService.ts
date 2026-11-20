import { NavData } from "../types";

const ESP32_IP = "192.168.4.1";

export const NavigationService = {
  async fetchNextNode(markerId: number, destinationId: number | null): Promise<NavData> {
    try {
      // Use the local proxy endpoint to avoid Mixed Content/CORS issues
      const url = `/api/node?current=${markerId}${destinationId ? `&destination=${destinationId}` : ''}`;
      const response = await fetch(url, {
        method: 'GET',
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || `Proxy returned ${response.status}`);
      }

      const data = await response.json();
      return data as NavData;
    } catch (error: any) {
      console.error("NavigationService Error:", error.message);
      throw new Error(error.message || "ESP32 Unreachable via Proxy.");
    }
  },

  // Mock function for testing in browser without ESP32
  async mockFetchNextNode(markerId: number, destinationId: number | null): Promise<NavData> {
    await new Promise(resolve => setTimeout(resolve, 800)); // Simulate network delay
    
    if (markerId === destinationId) {
      return { next: markerId, instruction: "You have arrived at your destination!", destinationReached: true };
    }

    const mockData: Record<number, NavData> = {
      1: { next: 2, instruction: `Heading to Node ${destinationId || '?'}. Go to the corridor.`, destinationReached: false },
      2: { next: 3, instruction: "Go straight for 10 meters", destinationReached: false },
      3: { next: 4, instruction: "Target room is on your right", destinationReached: false },
      4: { next: 1, instruction: "Turn back, you missed the room", destinationReached: false },
    };

    return mockData[markerId] || { next: 0, instruction: "Unknown marker detected", destinationReached: false };
  }
};
