export interface NavData {
  next: number;
  instruction: string;
  destinationReached: boolean;
}

export interface NavState {
  currentNode: number | null;
  nextNode: number | null;
  destination: number | null;
  instruction: string;
  connectionStatus: 'connected' | 'disconnected' | 'connecting';
  isLoading: boolean;
  error: string | null;
}
