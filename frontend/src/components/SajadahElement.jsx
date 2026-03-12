import React from 'react';
import { motion } from 'framer-motion';

const SajadahElement = ({ isBooked, delay, index, isMinified, isOverflow }) => {
    const bookedBg = 'bg-gradient-to-b from-emerald-800/80 to-emerald-950/90';
    const bookedBorder = 'border-emerald-600/25';
    const glowColor = 'rgba(16, 185, 129, 0.12)';
    const labelColor = 'text-emerald-400';
    const archColor = 'border-emerald-500/15';
    const accentColor = 'bg-emerald-400/15';
    const dotColor = 'bg-emerald-400/25';

    if (isMinified) {
        return (
            <motion.div
                layout
                className="h-4 w-full rounded-sm bg-emerald-800/50 border border-white/[0.04]"
                title={`Platz ${index + 1}`}
            />
        );
    }

    return (
        <motion.div
            layout
            initial={{ scale: 0.8, opacity: 0, y: 10 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            transition={{
                delay: delay * 0.15,
                duration: 0.5,
                ease: [0.23, 1, 0.32, 1]
            }}
            className="relative group w-full"
        >
            <div className={`
                relative w-full aspect-[2/3] rounded-lg transition-all duration-500 border
                ${isBooked
                    ? `${bookedBg} ${bookedBorder} shadow-lg`
                    : 'bg-white/[0.015] border-white/[0.04] opacity-35 hover:opacity-60 hover:scale-105 hover:border-white/[0.08] active:scale-95'}
            `}
                style={isBooked ? { boxShadow: `0 4px 20px ${glowColor}` } : {}}
            >
                {/* Mihrab arch pattern */}
                {isBooked && (
                    <>
                        <div className={`absolute top-[10%] left-[15%] right-[15%] h-[45%] border-t-2 border-l border-r ${archColor} rounded-t-full`} />
                        <div className={`absolute top-[18%] left-[25%] right-[25%] h-[30%] border-t border-l border-r ${archColor} rounded-t-full`} />
                        <div className={`absolute top-[14%] left-1/2 -translate-x-1/2 w-1.5 h-1.5 ${dotColor} rounded-full`} />
                        <div className={`absolute bottom-[15%] left-[20%] right-[20%] h-px ${accentColor}`} />
                        <div className={`absolute bottom-[22%] left-[30%] right-[30%] h-px ${accentColor}`} />
                    </>
                )}

                {!isBooked && (
                    <>
                        <div className="absolute top-[20%] left-[25%] right-[25%] h-[30%] border-t border-white/[0.03] rounded-t-full" />
                        <div className="absolute bottom-[20%] left-[30%] right-[30%] h-px bg-white/[0.02]" />
                    </>
                )}

                {isBooked && (
                    <motion.div
                        animate={{ opacity: [0.03, 0.12, 0.03] }}
                        transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
                        className="absolute inset-0 rounded-lg pointer-events-none"
                        style={{ background: `radial-gradient(ellipse at center top, ${glowColor}, transparent 70%)` }}
                    />
                )}

                <div className={`absolute -bottom-7 left-1/2 -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-all duration-300 font-bold text-[9px] ${labelColor} tracking-tight whitespace-nowrap z-10`}>
                    {index + 1} m²
                </div>
            </div>
        </motion.div>
    );
};

export default SajadahElement;
