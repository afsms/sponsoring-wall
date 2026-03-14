import React, { useState, useEffect, useRef, useMemo } from 'react';
import confetti from 'canvas-confetti';
import { motion, AnimatePresence } from 'framer-motion';
import { Users, LayoutGrid, Euro, Heart, Target, Sparkles } from 'lucide-react';
import { supabase, subscribeToSponsors } from '../lib/supabaseClient';
import StatsSidebar from '../components/StatsSidebar';
import SajadahElement from '../components/SajadahElement';

const Dashboard = () => {
    const [stats, setStats] = useState({
        totalSponsors: 0,
        totalSqMeters: 0,
        totalAmount: 0,
        bookedIndices: [],
    });
    const [chatMessages, setChatMessages] = useState([]);
    const [milestoneCelebration, setMilestoneCelebration] = useState(null);
    const lastProgressRef = useRef(0);

    const BASE_GOAL = 710;
    const COLS = 10;
    const ROW_BLOCK = COLS * 2;

    const triggerMilestoneConfetti = () => {
        const count = 300;
        const defaults = { origin: { y: 0.7 } };
        function fire(ratio, opts) {
            confetti({ ...defaults, ...opts, particleCount: Math.floor(count * ratio) });
        }
        fire(0.25, { spread: 26, startVelocity: 55 });
        fire(0.2, { spread: 60 });
        fire(0.35, { spread: 100, decay: 0.91, scalar: 0.8 });
        fire(0.1, { spread: 120, startVelocity: 25, decay: 0.92, scalar: 1.2 });
        fire(0.1, { spread: 120, startVelocity: 45 });
    };

    useEffect(() => {
        const fetchInitialState = async () => {
            const { data, error } = await supabase
                .from('sponsors')
                .select('*')
                .order('created_at', { ascending: false });

            if (data && !error) {
                const totalSq = data.reduce((sum, item) => sum + Number(item.sq_meters || 0), 0);
                const totalAmtBank = data.filter(s => s.iban !== 'CASH').reduce((sum, item) => sum + Number(item.total_amount || 0), 0);
                const totalAmtCash = data.filter(s => s.iban === 'CASH').reduce((sum, item) => sum + Number(item.total_amount || 0), 0);
                const initialIndices = Array.from({ length: totalSq }, (_, i) => i);

                setStats({
                    totalSponsors: data.length,
                    totalSqMeters: totalSq,
                    totalAmount: totalAmtBank,
                    totalAmountCash: totalAmtCash,
                    bookedIndices: initialIndices
                });

                const initialMessages = data.slice(0, 12).map(s => ({
                    id: s.id,
                    name: s.is_anonymous ? 'Anonym' : s.full_name,
                    amount: s.sq_meters,
                    time: new Date(s.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                }));
                setChatMessages(initialMessages);
                lastProgressRef.current = Math.floor((totalSq / BASE_GOAL) * 10);
            }
        };
        fetchInitialState();

        const unsubscribe = subscribeToSponsors((payload) => {
            const data = payload.new;
            if (!data) return;

            const newMessage = {
                id: data.id || Date.now(),
                name: data.is_anonymous ? 'Anonym' : data.full_name,
                amount: data.sq_meters,
                time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
            };
            setChatMessages(prev => [newMessage, ...prev].slice(0, 15));

            setStats(prev => {
                const sqToAdd = Number(data.sq_meters || 0);
                const newTotal = prev.totalSqMeters + sqToAdd;

                const currentProgInt = Math.floor((newTotal / BASE_GOAL) * 10);
                if (currentProgInt > lastProgressRef.current) {
                    setMilestoneCelebration(currentProgInt * 10);
                    triggerMilestoneConfetti();
                    setTimeout(() => setMilestoneCelebration(null), 10000);
                    lastProgressRef.current = currentProgInt;
                }

                return {
                    ...prev,
                    totalSponsors: prev.totalSponsors + 1,
                    totalSqMeters: newTotal,
                    totalAmount: data.iban !== 'CASH'
                        ? prev.totalAmount + Number(data.total_amount || 0)
                        : prev.totalAmount,
                    totalAmountCash: data.iban === 'CASH'
                        ? prev.totalAmountCash + Number(data.total_amount || 0)
                        : prev.totalAmountCash,
                    bookedIndices: Array.from({ length: newTotal }, (_, i) => i)
                };
            });
        });

        return () => unsubscribe();
    }, []);

    const { minifiedUnits, activeUnits } = useMemo(() => {
        const bookedCount = stats.bookedIndices.length;
        const cappedBooked = Math.min(bookedCount, BASE_GOAL);

        // If we reached the goal, archive everything
        if (bookedCount >= BASE_GOAL) {
            return {
                minifiedUnits: Array.from({ length: BASE_GOAL }, (_, i) => i),
                activeUnits: []
            };
        }

        const fullBlocksCount = Math.floor(cappedBooked / ROW_BLOCK);
        const minified = Array.from({ length: fullBlocksCount * ROW_BLOCK }, (_, i) => i);
        const remaining = BASE_GOAL - minified.length;
        const active = Array.from({ length: remaining }, (_, i) => i + minified.length);

        return { minifiedUnits: minified, activeUnits: active };
    }, [stats.bookedIndices, stats.totalSqMeters]);

    const overflowM2 = Math.max(0, stats.totalSqMeters - BASE_GOAL);
    const goalReached = stats.totalSqMeters >= BASE_GOAL;

    // Progress bar
    const totalForBar = Math.max(stats.totalSqMeters, BASE_GOAL);
    const greenPercent = goalReached
        ? (BASE_GOAL / totalForBar * 100)
        : (stats.totalSqMeters / BASE_GOAL * 100);
    const goldPercent = goalReached ? (overflowM2 / totalForBar * 100) : 0;

    return (
        <div className="dashboard-container bg-[#030303] flex-col min-h-screen relative overflow-hidden font-inter">

            {/* Ambient Background - green */}
            <div className="fixed inset-0 pointer-events-none z-0">
                <div className="absolute top-0 left-1/4 w-[500px] h-[500px] bg-emerald-500/[0.02] rounded-full blur-[150px]" />
                <div className="absolute bottom-1/3 right-0 w-[300px] h-[300px] bg-emerald-400/[0.015] rounded-full blur-[120px]" />
            </div>

            {/* Milestone Celebration */}
            <AnimatePresence>
                {milestoneCelebration && (
                    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[200] flex items-center justify-center bg-black/85 backdrop-blur-2xl">
                        <motion.div initial={{ scale: 0.5, y: 100 }} animate={{ scale: 1, y: 0 }} className="text-center">
                            <motion.div animate={{ opacity: [0.5, 1, 0.5] }} transition={{ repeat: Infinity, duration: 2 }} className="text-emerald-400 text-sm font-black uppercase tracking-[0.5em] mb-6">
                                <Sparkles className="inline mr-3" size={16} />Meilenstein Erreicht!<Sparkles className="inline ml-3" size={16} />
                            </motion.div>
                            <h2 className="text-[12rem] font-black text-white leading-none mb-4">{milestoneCelebration}%</h2>
                            <motion.div animate={{ scale: [1, 1.2, 1] }} transition={{ repeat: Infinity, duration: 2 }} className="mt-12 text-emerald-400 flex justify-center"><Heart size={64} fill="currentColor" /></motion.div>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Live Chat Overlay */}
            <div className="fixed bottom-8 left-8 z-[100] w-80 pointer-events-none">
                <div className="space-y-2 flex flex-col-reverse max-h-[400px] overflow-hidden">
                    <AnimatePresence mode='popLayout'>
                        {chatMessages.map((msg) => (
                            <motion.div key={msg.id} layout initial={{ opacity: 0, x: -30, scale: 0.9 }} animate={{ opacity: 0.9, x: 0, scale: 1 }} exit={{ opacity: 0, scale: 0.8 }} transition={{ type: 'spring', damping: 20, stiffness: 300 }}
                                className="bg-gradient-to-r from-black/60 to-black/30 backdrop-blur-xl border border-white/[0.06] p-3.5 rounded-2xl flex items-start space-x-3 shadow-[0_4px_30px_rgba(0,0,0,0.3)]">
                                <div className="mt-1.5 w-2 h-2 bg-emerald-400 rounded-full shadow-[0_0_8px_rgba(52,211,153,0.5)]" />
                                <div className="flex-grow min-w-0">
                                    <div className="flex justify-between items-center mb-1">
                                        <span className="text-white/90 text-xs font-bold truncate">{msg.name}</span>
                                        <span className="text-white/30 text-[9px] font-medium ml-2 flex-shrink-0">{msg.time}</span>
                                    </div>
                                    <div className="text-emerald-400/80 text-[11px] font-medium">hat <span className="text-white font-bold">{msg.amount} m²</span> gespendet</div>
                                </div>
                            </motion.div>
                        ))}
                    </AnimatePresence>
                </div>
            </div>

            <div className="flex flex-grow w-full relative h-screen overflow-hidden z-10">

                {/* Main Content */}
                <div className="flex-grow relative p-10 overflow-y-auto custom-scrollbar h-full">
                    <div className="max-w-[1400px] mx-auto pb-40">

                        {/* PROGRESS SECTION */}
                        <div className="mb-14 space-y-5">
                            <div className="flex items-end justify-between">
                                <div className="space-y-1">
                                    <div className="text-white/30 text-[10px] font-bold uppercase tracking-[0.3em] flex items-center gap-2">
                                        <Target size={12} />Aktueller Fortschritt
                                    </div>
                                    <div className="flex items-baseline space-x-2">
                                        <span className="text-6xl font-black text-white tracking-tighter">{Math.min(stats.totalSqMeters, BASE_GOAL)}</span>
                                        <span className="text-2xl font-bold text-white/20 uppercase tracking-widest">/ {BASE_GOAL} m²</span>
                                    </div>
                                </div>
                                <div className="text-right">
                                    <div className="text-emerald-400 text-6xl font-black tracking-tighter">
                                        {((stats.totalSqMeters / BASE_GOAL) * 100).toFixed(1)}%
                                    </div>
                                    <div className="text-white/20 text-[10px] font-bold uppercase tracking-[0.2em] mt-1">der Gesamtfläche finanziert</div>
                                </div>
                            </div>

                            {/* Progress Bar */}
                            <div className="space-y-2">
                                {/* Labels */}
                                <div className="flex items-center gap-6 text-[10px] font-bold uppercase tracking-[0.15em]">
                                    <div className="flex items-center gap-2">
                                        <div className="w-3 h-3 rounded-sm bg-gradient-to-r from-emerald-700 to-emerald-400" />
                                        <span className="text-emerald-400/60">Miete & Kosten</span>
                                        <span className="text-white/20">({Math.min(stats.totalSqMeters, BASE_GOAL)}/{BASE_GOAL} m²)</span>
                                    </div>
                                    {goalReached && overflowM2 > 0 && (
                                        <div className="flex items-center gap-2">
                                            <div className="w-3 h-3 rounded-sm bg-gradient-to-r from-[#8a6d2b] to-[#c9a84c]" />
                                            <span className="text-[#c9a84c]/60">Moschee Kauf</span>
                                            <span className="text-white/20">(+{overflowM2} m²)</span>
                                        </div>
                                    )}
                                </div>

                                {/* Bar */}
                                <div className="relative h-5 bg-white/[0.04] rounded-full overflow-hidden border border-white/[0.04] flex">
                                    {/* Miete & Kosten (Green) */}
                                    <motion.div
                                        initial={{ width: 0 }}
                                        animate={{ width: `${greenPercent}%` }}
                                        transition={{ duration: 1.5, ease: [0.23, 1, 0.32, 1] }}
                                        className="h-full relative overflow-hidden"
                                        style={{
                                            background: 'linear-gradient(90deg, #065f46, #10b981, #34d399)',
                                            boxShadow: '0 0 30px rgba(16,185,129,0.25)'
                                        }}
                                    >
                                        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent"
                                            style={{ animation: 'shimmer 2s infinite linear', backgroundSize: '200% 100%' }} />
                                    </motion.div>

                                    {/* Moschee Kauf (Gold) - only when goal reached */}
                                    {goalReached && goldPercent > 0 && (
                                        <motion.div
                                            initial={{ width: 0 }}
                                            animate={{ width: `${goldPercent}%` }}
                                            transition={{ duration: 1.5, delay: 0.3, ease: [0.23, 1, 0.32, 1] }}
                                            className="h-full relative overflow-hidden border-l border-white/10"
                                            style={{
                                                background: 'linear-gradient(90deg, #8a6d2b, #c9a84c, #d4b85c)',
                                                boxShadow: '0 0 25px rgba(201,168,76,0.3)'
                                            }}
                                        >
                                            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/15 to-transparent"
                                                style={{ animation: 'shimmer 2.5s infinite linear', backgroundSize: '200% 100%' }} />
                                        </motion.div>
                                    )}
                                </div>
                            </div>
                        </div>

                        {/* ARCHIVIERTE REIHEN */}
                        {minifiedUnits.length > 0 && (() => {
                            const rowBlockSize = ROW_BLOCK;
                            const numBlocks = Math.floor(minifiedUnits.length / rowBlockSize);
                            const archivedM2 = Math.min(minifiedUnits.length, BASE_GOAL);
                            return (
                                <div className="mb-14">
                                    {/* Header */}
                                    <div className="flex items-center justify-between mb-8 px-2">
                                        <div className="flex items-center gap-4">
                                            <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 flex items-center justify-center border border-emerald-500/10">
                                                <LayoutGrid size={20} className="text-emerald-400/60" />
                                            </div>
                                            <div>
                                                <div className="text-white/40 text-sm font-bold uppercase tracking-[0.15em]">Bereits reserviert</div>
                                                <div className="text-white/15 text-xs font-medium mt-1">{numBlocks} abgeschlossene Reihen · {archivedM2} m²</div>
                                            </div>
                                        </div>
                                        <div className="text-right flex items-baseline gap-2">
                                            <span className="text-emerald-400/50 text-4xl font-black">{archivedM2}</span>
                                            <span className="text-white/15 text-xs uppercase tracking-wider">m²</span>
                                        </div>
                                    </div>

                                    {/* Card Grid */}
                                    <div className="grid grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3">
                                        {Array.from({ length: numBlocks }).map((_, blockIdx) => {
                                            const startM2 = blockIdx * rowBlockSize + 1;
                                            const endM2 = (blockIdx + 1) * rowBlockSize;
                                            const intensity = 0.06 + (blockIdx / Math.max(numBlocks, 1)) * 0.1;
                                            return (
                                                <motion.div
                                                    key={blockIdx}
                                                    initial={{ opacity: 0, scale: 0.9 }}
                                                    animate={{ opacity: 1, scale: 1 }}
                                                    transition={{ delay: blockIdx * 0.02, duration: 0.4, ease: [0.23, 1, 0.32, 1] }}
                                                    className="group relative rounded-2xl border border-white/[0.04] overflow-hidden hover:border-emerald-500/15 transition-all duration-500 cursor-default"
                                                    style={{ background: `linear-gradient(135deg, rgba(16,185,129,${intensity * 0.3}), rgba(6,78,59,${intensity * 0.5}))` }}
                                                >
                                                    <div className="h-0.5 bg-gradient-to-r from-emerald-500/20 via-emerald-400/30 to-emerald-500/20" />
                                                    <div className="p-5 relative">
                                                        <div className="text-emerald-400/15 text-3xl font-black absolute top-3 right-4 group-hover:text-emerald-400/25 transition-colors duration-500">
                                                            {String(blockIdx + 1).padStart(2, '0')}
                                                        </div>
                                                        <div className="text-emerald-400/40 text-xs font-bold tracking-wider mb-2 group-hover:text-emerald-400/60 transition-colors duration-500">
                                                            {startM2}–{endM2} m²
                                                        </div>
                                                        <div className="flex items-center gap-2">
                                                            <div className="w-2 h-2 rounded-full bg-emerald-500/40" />
                                                            <span className="text-white/20 text-[10px] font-medium uppercase tracking-wider group-hover:text-white/30 transition-colors">Reserviert</span>
                                                        </div>
                                                    </div>
                                                    <div className="absolute inset-0 bg-emerald-500/[0.02] opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none" />
                                                </motion.div>
                                            );
                                        })}
                                    </div>
                                </div>
                            );
                        })()}

                        {/* ACTIVE GRID - only shows if not all 710 filled */}
                        {activeUnits.length > 0 && (
                            <div className="relative">
                                <div className="flex items-center justify-between text-[10px] text-white/20 font-bold uppercase tracking-[0.2em] px-4 mb-4">
                                    <span className="flex items-center gap-2">
                                        🕌 Aktuelle Fläche – Moschee Abo
                                    </span>
                                    <span className="flex items-center gap-2">
                                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                                        Live
                                    </span>
                                </div>
                                <div className="grid grid-cols-5 md:grid-cols-8 lg:grid-cols-10 gap-6 w-full relative overflow-hidden p-14 rounded-[4rem] border border-emerald-900/20"
                                    style={{
                                        background: 'linear-gradient(180deg, #030f0a 0%, #040804 50%, #050505 100%)',
                                        boxShadow: '0 0 120px rgba(16,185,129,0.03), inset 0 1px 0 rgba(16,185,129,0.04)'
                                    }}
                                >
                                    {/* Mosque arch */}
                                    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-40 h-20 border-b-2 border-emerald-700/20 rounded-b-full" />
                                    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-24 h-12 border-b border-emerald-600/15 rounded-b-full" />
                                    <div className="absolute top-4 left-1/2 -translate-x-1/2 text-emerald-700/20 text-2xl">☪</div>

                                    {/* Corner ornaments */}
                                    <div className="absolute top-6 left-6 w-8 h-8 border-l border-t border-emerald-800/15 rounded-tl-lg" />
                                    <div className="absolute top-6 right-6 w-8 h-8 border-r border-t border-emerald-800/15 rounded-tr-lg" />
                                    <div className="absolute bottom-6 left-6 w-8 h-8 border-l border-b border-emerald-800/15 rounded-bl-lg" />
                                    <div className="absolute bottom-6 right-6 w-8 h-8 border-r border-b border-emerald-800/15 rounded-br-lg" />

                                    <div className="absolute -top-40 left-1/2 -translate-x-1/2 w-[500px] h-[300px] bg-emerald-500/[0.03] blur-[120px] rounded-full" />

                                    {activeUnits.map((idx) => (
                                        <SajadahElement
                                            key={idx}
                                            index={idx}
                                            isBooked={idx < stats.bookedIndices.length}
                                            isOverflow={false}
                                            delay={(idx % COLS) * 0.02}
                                        />
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Right Sidebar */}
                <div className="w-[380px] flex flex-col bg-[#040404] border-l border-white/[0.04] shadow-2xl relative z-40">
                    <div className="p-8"><StatsSidebar data={stats} goal={BASE_GOAL} /></div>
                </div>
            </div>

            {/* Bottom Progress Strip */}
            <div className="fixed bottom-0 left-0 right-0 z-[90] h-1 flex">
                <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${greenPercent}%` }}
                    transition={{ duration: 2, ease: 'easeOut' }}
                    className="h-full bg-gradient-to-r from-emerald-700 via-emerald-500 to-emerald-400"
                    style={{ boxShadow: '0 0 15px rgba(52,211,153,0.4)' }}
                />
                {goalReached && goldPercent > 0 && (
                    <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${goldPercent}%` }}
                        transition={{ duration: 2, delay: 0.5, ease: 'easeOut' }}
                        className="h-full bg-gradient-to-r from-[#8a6d2b] via-[#c9a84c] to-[#d4b85c]"
                        style={{ boxShadow: '0 0 15px rgba(201,168,76,0.4)' }}
                    />
                )}
            </div>
        </div>
    );
};

export default Dashboard;
