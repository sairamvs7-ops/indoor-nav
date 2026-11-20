import React, { createContext, useContext, useState, useCallback } from 'react';
import { NavState } from '../types';
import { NavigationService } from '../services/NavigationService';

interface NavigationContextType extends NavState {
  processScan: (markerId: number) => Promise<void>;
  setDestination: (id: number | null) => void;
  resetError: () => void;
}

const NavigationContext = createContext<NavigationContextType | undefined>(undefined);

export const NavigationProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<NavState>({
    currentNode: null,
    nextNode: null,
    destination: null,
    instruction: "Select a destination and scan a marker.",
    connectionStatus: 'disconnected',
    isLoading: false,
    error: null,
  });

  const setDestination = (id: number | null) => {
    setState(prev => ({ ...prev, destination: id }));
  };

  const resetError = () => setState(prev => ({ ...prev, error: null }));

  const processScan = useCallback(async (markerId: number) => {
    setState(prev => ({ ...prev, isLoading: true, error: null, currentNode: markerId }));
    
    try {
      // Attempt real ESP32 fetch, fall back to mock if it fails or if we're in a dev environment
      let data;
      try {
        data = await NavigationService.fetchNextNode(markerId, state.destination);
        setState(prev => ({ ...prev, connectionStatus: 'connected' }));
      } catch (e) {
        console.warn("ESP32 failed, using mock data for demo...");
        data = await NavigationService.mockFetchNextNode(markerId, state.destination);
        setState(prev => ({ ...prev, connectionStatus: 'disconnected' }));
      }

      setState(prev => ({
        ...prev,
        nextNode: data.next,
        instruction: data.instruction,
        isLoading: false,
      }));
    } catch (err: any) {
      setState(prev => ({
        ...prev,
        isLoading: false,
        error: err.message || "Failed to communicate with ESP32",
      }));
    }
  }, [state.destination]);

  return (
    <NavigationContext.Provider value={{ ...state, processScan, setDestination, resetError }}>
      {children}
    </NavigationContext.Provider>
  );
};

export const useNavigation = () => {
  const context = useContext(NavigationContext);
  if (!context) throw new Error('useNavigation must be used within a NavigationProvider');
  return context;
};
