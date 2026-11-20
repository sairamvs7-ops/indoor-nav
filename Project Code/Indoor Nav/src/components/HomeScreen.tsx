import React from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'motion/react';
import { useNavigation } from '../context/NavigationContext';
import { MapPin, ArrowRight, Navigation, Wifi, WifiOff, Loader2, Camera } from 'lucide-react';
import { cn } from '../lib/utils';

export const HomeScreen: React.FC = () => {
  const navigate = useNavigate();
  const { currentNode, nextNode, destination, setDestination, instruction, connectionStatus, isLoading, error, resetError } = useNavigation();

  return (
    <div className="flex flex-col min-h-screen bg-[#0a0a0a] text-white font-sans p-6">
      {/* Header */}
      <header className="flex justify-between items-center mb-8 mt-4">
        <div className="flex flex-col">
          <h1 className="text-2xl font-bold tracking-tight">IndoorNav</h1>
          <p className="text-xs text-zinc-500 uppercase tracking-widest font-mono">Pro Version 1.0</p>
        </div>
        <div className={cn(
          "flex items-center gap-2 px-3 py-1 rounded-full text-[10px] font-mono uppercase tracking-wider border",
          connectionStatus === 'connected' ? "border-emerald-500/30 text-emerald-400 bg-emerald-500/5" : "border-zinc-800 text-zinc-500"
        )}>
          {connectionStatus === 'connected' ? <Wifi size={12} /> : <WifiOff size={12} />}
          {connectionStatus}
        </div>
      </header>

      {/* Destination Selector */}
      <section className="mb-8">
        <label className="text-[10px] text-zinc-500 uppercase font-mono mb-2 block tracking-widest">Select Destination</label>
        <div className="flex gap-2 overflow-x-auto pb-2 no-scrollbar">
          {[1, 2, 3, 4].map(id => (
            <button
              key={id}
              onClick={() => setDestination(id)}
              className={cn(
                "px-6 py-3 rounded-xl border transition-all whitespace-nowrap font-medium",
                destination === id 
                  ? "bg-emerald-500 border-emerald-400 text-black" 
                  : "bg-zinc-900 border-zinc-800 text-zinc-400"
              )}
            >
              Room {100 + id}
            </button>
          ))}
        </div>
      </section>

      {/* Main Display */}
      <main className="flex-1 flex flex-col gap-8">
        {/* Status Cards */}
        <div className="grid grid-cols-2 gap-4">
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-zinc-900/50 border border-zinc-800 p-4 rounded-2xl flex flex-col gap-1"
          >
            <span className="text-[10px] text-zinc-500 uppercase font-mono">Current Node</span>
            <div className="flex items-center gap-2">
              <MapPin size={16} className="text-emerald-500" />
              <span className="text-xl font-medium">{currentNode ?? "--"}</span>
            </div>
          </motion.div>

          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="bg-zinc-900/50 border border-zinc-800 p-4 rounded-2xl flex flex-col gap-1"
          >
            <span className="text-[10px] text-zinc-500 uppercase font-mono">Next Node</span>
            <div className="flex items-center gap-2">
              <ArrowRight size={16} className="text-blue-500" />
              <span className="text-xl font-medium">{nextNode ?? "--"}</span>
            </div>
          </motion.div>
        </div>

        {/* Instruction Panel */}
        <motion.div 
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.2 }}
          className="flex-1 flex flex-col items-center justify-center text-center p-8 bg-zinc-900/30 border border-zinc-800/50 rounded-[2rem] relative overflow-hidden"
        >
          <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-blue-500 via-emerald-500 to-blue-500 animate-pulse" />
          
          <Navigation size={48} className="text-emerald-500/20 mb-6" />
          
          {isLoading ? (
            <div className="flex flex-col items-center gap-4">
              <Loader2 size={32} className="animate-spin text-emerald-500" />
              <p className="text-zinc-400 font-mono text-sm">Calculating Route...</p>
            </div>
          ) : (
            <h2 className={cn(
              "text-3xl font-light leading-tight tracking-tight",
              currentNode ? "text-white" : "text-zinc-500 italic"
            )}>
              {instruction}
            </h2>
          )}

          {error && (
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="mt-6 p-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-xs font-mono"
            >
              {error}
              <button onClick={resetError} className="ml-2 underline">Dismiss</button>
            </motion.div>
          )}
        </motion.div>
      </main>

      {/* Footer Action */}
      <footer className="py-8">
        <button
          onClick={() => navigate('/scanner')}
          disabled={isLoading}
          className="w-full bg-white text-black h-16 rounded-2xl font-bold text-lg flex items-center justify-center gap-3 active:scale-95 transition-transform disabled:opacity-50"
        >
          <Camera size={24} />
          Start Scan
        </button>
      </footer>
    </div>
  );
};
