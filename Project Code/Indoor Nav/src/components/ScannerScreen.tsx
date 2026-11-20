import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'motion/react';
import { useNavigation } from '../context/NavigationContext';
import { X, Camera, Loader2, Scan, CheckCircle2 } from 'lucide-react';
import { cn } from '../lib/utils';

// Safer import for js-aruco which might not have standard ESM exports
let AR: any;
try {
  // @ts-ignore
  if (window.AR) {
    // @ts-ignore
    AR = window.AR;
  } else {
    import('js-aruco').then(module => {
      AR = module.AR || module;
    }).catch(err => {
      console.error("Failed to load js-aruco module:", err);
    });
  }
} catch (e) {
  console.error("ArUco initialization error:", e);
}

export const ScannerScreen: React.FC = () => {
  const navigate = useNavigate();
  const { processScan } = useNavigation();
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const detectorRef = useRef<any>(null);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [isReady, setIsReady] = useState(false);
  const [isScanning, setIsScanning] = useState(true);
  const [detectedId, setDetectedId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [debugMode, setDebugMode] = useState(false);

  // Initialize ArUco Detector
  useEffect(() => {
    const initDetector = () => {
      // @ts-ignore
      const aruco = window.AR || AR;
      if (aruco && aruco.Detector) {
        try {
          detectorRef.current = new aruco.Detector();
          console.log("ArUco Detector Initialized successfully");
          return true;
        } catch (e) {
          console.error("Error creating ArUco detector:", e);
        }
      }
      return false;
    };

    if (!initDetector()) {
      const interval = setInterval(() => {
        if (initDetector()) {
          clearInterval(interval);
        }
      }, 500);
      return () => clearInterval(interval);
    }
  }, []);

  // Initialize Camera
  useEffect(() => {
    const startCamera = async () => {
      try {
        const mediaStream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment', width: { ideal: 640 }, height: { ideal: 480 } }
        });
        setStream(mediaStream);
        if (videoRef.current) {
          videoRef.current.srcObject = mediaStream;
          setIsReady(true);
        }
      } catch (err) {
        console.error("Camera access error:", err);
        setError("Camera access denied. Please check permissions.");
      }
    };

    startCamera();

    return () => {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
    };
  }, []);

  // Real-time ArUco Detection Loop
  useEffect(() => {
    if (!isReady || !isScanning) return;

    let animationFrameId: number;
    let lastProcessedTime = 0;
    const PROCESS_INTERVAL = 60; // Slightly faster processing for better detection

    const detect = (time: number) => {
      if (!videoRef.current || !canvasRef.current || !isScanning) return;

      if (time - lastProcessedTime < PROCESS_INTERVAL) {
        animationFrameId = requestAnimationFrame(detect);
        return;
      }
      lastProcessedTime = time;

      const video = videoRef.current;
      const canvas = canvasRef.current;
      const context = canvas.getContext('2d', { willReadFrequently: true });

      if (context && video.readyState === video.HAVE_ENOUGH_DATA) {
        // Match canvas size to video
        if (canvas.width !== video.videoWidth || canvas.height !== video.videoHeight) {
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
        }

        context.drawImage(video, 0, 0, canvas.width, canvas.height);
        
        // Only attempt detection if detector is ready
        if (detectorRef.current) {
          const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
          
          try {
            const markers = detectorRef.current.detect(imageData);
            
            // Draw debug info if enabled
            if (debugMode && markers) {
              context.strokeStyle = "#00ff00"; // Use green for debug lines
              context.lineWidth = 4;
              markers.forEach((marker: any) => {
                context.beginPath();
                context.moveTo(marker.corners[0].x, marker.corners[0].y);
                for (let i = 1; i < 4; i++) {
                  context.lineTo(marker.corners[i].x, marker.corners[i].y);
                }
                context.closePath();
                context.stroke();
                
                // Draw ID
                context.fillStyle = "#00ff00";
                context.font = "bold 24px monospace";
                context.fillText(`ID: ${marker.id}`, marker.corners[0].x, marker.corners[0].y - 10);
              });
            }

            if (markers && markers.length > 0) {
              console.log("Marker Detected:", markers[0].id);
              handleDetection(markers[0].id);
              return; 
            }
          } catch (err) {
            console.error("Detection error:", err);
          }
        }
      }

      animationFrameId = requestAnimationFrame(detect);
    };

    animationFrameId = requestAnimationFrame(detect);

    return () => {
      cancelAnimationFrame(animationFrameId);
    };
  }, [isReady, isScanning, debugMode]);

  const handleDetection = async (id: number) => {
    if (!isScanning) return;
    
    setIsScanning(false);
    setDetectedId(id);
    
    // Visual feedback delay
    await new Promise(resolve => setTimeout(resolve, 800));
    
    // Process the scan
    await processScan(id);
    
    // Navigate back
    navigate('/');
  };

  const handleSimulateDetection = (id: number) => {
    handleDetection(id);
  };

  const handleClose = () => {
    if (stream) {
      stream.getTracks().forEach(track => track.stop());
    }
    navigate('/');
  };

  return (
    <div className="fixed inset-0 bg-black z-50 flex flex-col overflow-hidden">
      {/* Processing Canvas (Visible in debug mode) */}
      <canvas 
        ref={canvasRef} 
        className={cn(
          "absolute inset-0 z-20 pointer-events-none w-full h-full object-cover",
          debugMode ? "opacity-100" : "opacity-0"
        )} 
      />

      {/* Camera Viewport */}
      <div className="relative flex-1 bg-zinc-900">
        {!isReady && !error && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 text-zinc-500">
            <Loader2 size={32} className="animate-spin" />
            <p className="font-mono text-xs uppercase tracking-widest">Initializing Camera...</p>
          </div>
        )}

        {error && (
          <div className="absolute inset-0 flex flex-col items-center justify-center p-8 text-center gap-4">
            <X size={48} className="text-red-500" />
            <p className="text-red-400 font-mono text-sm">{error}</p>
            <button 
              onClick={handleClose}
              className="mt-4 px-6 py-2 bg-white text-black rounded-full font-bold"
            >
              Go Back
            </button>
          </div>
        )}

        <video
          ref={videoRef}
          autoPlay
          playsInline
          className="w-full h-full object-cover"
        />

        {/* Overlay UI */}
        <div className="absolute inset-0 pointer-events-none flex flex-col">
          {/* Top Bar */}
          <div className="p-6 flex justify-between items-center pointer-events-auto">
            <button 
              onClick={handleClose}
              className="w-10 h-10 bg-black/50 backdrop-blur-md rounded-full flex items-center justify-center text-white border border-white/10"
            >
              <X size={20} />
            </button>
            <button 
              onClick={() => setDebugMode(!debugMode)}
              className={cn(
                "px-4 py-1.5 backdrop-blur-md rounded-full border flex items-center gap-2 transition-colors",
                debugMode ? "bg-emerald-500/20 border-emerald-500 text-emerald-400" : "bg-black/50 border-white/10 text-white/50"
              )}
            >
              <span className="text-[10px] font-mono uppercase tracking-widest">Debug {debugMode ? 'ON' : 'OFF'}</span>
            </button>
            <div className="px-4 py-1.5 bg-black/50 backdrop-blur-md rounded-full border border-white/10 flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
              <span className="text-[10px] font-mono text-white uppercase tracking-widest">Live Scanner</span>
            </div>
          </div>

          {/* Scanning Frame */}
          <div className="flex-1 flex items-center justify-center p-12">
            <div className="relative w-full aspect-square max-w-[280px]">
              {/* Corner Brackets */}
              <div className="absolute top-0 left-0 w-8 h-8 border-t-2 border-l-2 border-emerald-500 rounded-tl-xl" />
              <div className="absolute top-0 right-0 w-8 h-8 border-t-2 border-r-2 border-emerald-500 rounded-tr-xl" />
              <div className="absolute bottom-0 left-0 w-8 h-8 border-b-2 border-l-2 border-emerald-500 rounded-bl-xl" />
              <div className="absolute bottom-0 right-0 w-8 h-8 border-b-2 border-r-2 border-emerald-500 rounded-br-xl" />
              
              {/* Scan Line */}
              {isScanning && (
                <motion.div 
                  animate={{ top: ['0%', '100%', '0%'] }}
                  transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
                  className="absolute left-0 right-0 h-0.5 bg-emerald-500/50 shadow-[0_0_15px_rgba(16,185,129,0.5)] z-10"
                />
              )}

              {/* Success Feedback */}
              {detectedId !== null && (
                <motion.div 
                  initial={{ scale: 0, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  className="absolute inset-0 flex flex-col items-center justify-center bg-emerald-500/20 backdrop-blur-sm rounded-xl"
                >
                  <CheckCircle2 size={64} className="text-emerald-400 mb-2" />
                  <span className="text-white font-bold text-xl">Node {detectedId}</span>
                  <span className="text-emerald-400 text-[10px] font-mono uppercase tracking-widest">Detected</span>
                </motion.div>
              )}
            </div>
          </div>

          {/* Bottom Instructions */}
          <div className="p-12 text-center">
            <p className="text-white/60 text-sm font-light tracking-wide">
              Align ArUco marker within the frame
            </p>
          </div>
        </div>
      </div>

      {/* Simulation Controls (Visible for demo) */}
      <div className="bg-zinc-950 p-6 border-t border-zinc-800">
        <div className="flex flex-col gap-4">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-mono text-zinc-500 uppercase tracking-widest">Simulation Mode</span>
            <Scan size={14} className="text-zinc-500" />
          </div>
          <div className="grid grid-cols-4 gap-2">
            {[1, 2, 3, 4].map(id => (
              <button
                key={id}
                onClick={() => handleSimulateDetection(id)}
                disabled={!isScanning}
                className={cn(
                  "h-12 rounded-xl font-mono text-sm border transition-all",
                  isScanning 
                    ? "bg-zinc-900 border-zinc-800 text-white active:bg-emerald-500 active:border-emerald-500" 
                    : "bg-zinc-900/50 border-zinc-900 text-zinc-700"
                )}
              >
                ID {id}
              </button>
            ))}
          </div>
          <p className="text-[10px] text-zinc-600 text-center italic">
            Tap an ID above to simulate ArUco marker detection
          </p>
        </div>
      </div>
    </div>
  );
};
