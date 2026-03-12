import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';

export default function Admin() {
  const [token, setToken] = useState(localStorage.getItem('adminToken') || '');
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  const [cashAmount, setCashAmount] = useState('');
  const [sqMetersCalc, setSqMetersCalc] = useState(0);
  const [pricePerUnit, setPricePerUnit] = useState(15);
  const [donationStatus, setDonationStatus] = useState('');

  const [sponsors, setSponsors] = useState([]);

  useEffect(() => {
    // Einfacher Passwortschutz
    if (token === 'admin123') {
      setIsAuthenticated(true);
      fetchSettings();
      fetchSponsors();
    }
  }, [token]);

  const handleLogin = (e) => {
    e.preventDefault();
    const inputToken = e.target.token.value;
    if (inputToken === 'admin123') {
      localStorage.setItem('adminToken', inputToken);
      setToken(inputToken);
    } else {
      alert('Falscher Token!');
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    setToken('');
    setIsAuthenticated(false);
  };

  const fetchSettings = async () => {
    const { data } = await supabase.from('project_settings').select('price_per_unit').single();
    if (data) setPricePerUnit(data.price_per_unit || 15);
  };

  const fetchSponsors = async () => {
    const { data } = await supabase.from('sponsors').select('*').order('created_at', { ascending: false });
    if (data) setSponsors(data);
  };

  const calculateSqMeters = (amount) => {
    if (!amount) return 0;
    // 1 Quadratmeter kostet pricePerUnit pro Monat. Im Jahr also pricePerUnit * 12
    const yearlyCost = pricePerUnit * 12;
    // Wie viele QM bekommt man für 'amount'?
    return Math.floor(amount / yearlyCost);
  };

  const exportBankCSV = () => {
    const data = sponsors.filter(s => s.iban !== 'CASH');
    let csv = 'Name,Email,Telefon,m2,IBAN,Mandat Akzeptiert\n';
    data.forEach(s => {
      csv += `"${s.full_name}","${s.email}","${s.phone || ''}","${s.sq_meters}","${s.iban}","${s.mandate_accepted ? 'Ja' : 'Nein'}"\n`;
    });
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'bank_registrierungen.csv');
    document.body.appendChild(link);
    link.click();
    link.remove();
  };

  const exportCashCSV = () => {
    const data = sponsors.filter(s => s.iban === 'CASH');
    let csv = 'Datum,Name,Email,m2,Betrag\n';
    data.forEach(s => {
      const date = new Date(s.created_at).toLocaleDateString('de-DE');
      csv += `"${date}","${s.sq_meters}","${s.total_amount || ''}"\n`;
    });
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'bar_spenden.csv');
    document.body.appendChild(link);
    link.click();
    link.remove();
  };

  const handleCashChange = (e) => {
    const val = e.target.value;
    setCashAmount(val);
    setSqMetersCalc(calculateSqMeters(parseFloat(val)));
  };

  const handleSaveDonation = async () => {
    if (sqMetersCalc <= 0) {
      alert('Der Betrag reicht nicht für mindestens einen Quadratmeter oder ist ungültig.');
      return;
    }

    const newSponsor = {
      full_name: 'Bar Spende',
      email: 'admin@sponsoring-wall.local',
      phone: '',
      iban: 'CASH',
      mandate_accepted: true,
      sq_meters: sqMetersCalc,
      total_amount: parseFloat(cashAmount),
      is_anonymous: false
    };

    const { error } = await supabase.from('sponsors').insert([newSponsor]);

    if (error) {
      console.error(error);
      setDonationStatus('Fehler beim Speichern! Überprüfe die Logs.');
    } else {
      setDonationStatus('Spende erfolgreich eingetragen!');
      setCashAmount('');
      setSqMetersCalc(0);
      fetchSponsors(); // Aktualisiert die Tabelle nach Eintrag
      setTimeout(() => setDonationStatus(''), 4000);
    }
  };

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-900 text-white font-sans">
        <form onSubmit={handleLogin} className="bg-gray-800 p-8 rounded-2xl shadow-2xl border border-white/5 w-full max-w-sm">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold text-white mb-2">Admin Dashboard</h2>
            <p className="text-gray-400 text-sm">Bitte gib dein Admin-Token ein.</p>
          </div>
          <input
            type="password"
            name="token"
            placeholder="Passwort (z.B. admin123)"
            className="w-full bg-gray-900 border border-gray-700/50 rounded-lg px-4 py-3 mb-6 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all font-mono"
            autoFocus
          />
          <button type="submit" className="w-full bg-emerald-500 hover:bg-emerald-600 text-white font-semibold py-3 px-4 rounded-lg shadow-lg hover:shadow-emerald-500/20 transition-all">
            Zugriff anfordern
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white p-4 md:p-8 font-sans">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-10 pb-6 border-b border-gray-800">
          <div>
            <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-teal-400 tracking-tight">Admin Interface</h1>
            <p className="text-gray-400 mt-1">Verwaltung von Barspenden und Sponsor-Übersicht</p>
          </div>
          <button onClick={handleLogout} className="mt-4 sm:mt-0 bg-red-500/10 border border-red-500/20 text-red-400 hover:bg-red-500 hover:text-white px-5 py-2.5 rounded-lg font-medium transition-all duration-200">
            Logout
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-12">
          {/* Card: Bar Spende Eingabe */}
          <div className="lg:col-span-1 bg-gray-800/80 backdrop-blur-sm p-6 sm:p-8 rounded-2xl border border-white/5 shadow-2xl">
            <div className="flex items-center mb-6">
              <div className="w-10 h-10 rounded-full bg-emerald-500/20 flex items-center justify-center text-emerald-400 mr-3">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
              </div>
              <h2 className="text-xl font-semibold text-white">Bar Spende eintragen</h2>
            </div>

            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">Empfangene Summe (€)</label>
                <div className="relative">
                  <input
                    type="number"
                    value={cashAmount}
                    onChange={handleCashChange}
                    min="0"
                    step="1"
                    placeholder="1000"
                    className="w-full bg-gray-200/50 border border-gray-700/50 rounded-xl px-4 py-8 pl-12 text-2xl font-bold text-gray-300 placeholder-gray-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all"
                  />
                  <span className="absolute left-4 top-1/2 -translate-y-1/2 text-2xl font-bold text-white">€</span>
                </div>
              </div>

              <div className="bg-gradient-to-br from-gray-900 to-gray-800 p-5 rounded-xl border border-gray-700/50 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/5 rounded-full blur-2xl -mr-10 -mt-10"></div>
                <p className="text-sm text-gray-400 mb-2 relative z-10 flex justify-between">
                  <span>Preis m²/Monat:</span>
                  <span className="font-mono text-gray-300">{pricePerUnit.toFixed(2)} €</span>
                </p>
                <p className="text-sm text-gray-400 mb-4 relative z-10 flex justify-between">
                  <span>Jahreskosten (x12):</span>
                  <span className="font-mono text-gray-300">{(pricePerUnit * 12).toFixed(2)} €</span>
                </p>
                <div className="pt-4 border-t border-gray-700/50 flex flex-col items-center relative z-10">
                  <span className="text-xs uppercase tracking-wider text-gray-500 font-semibold mb-1">Berechnete Fläche</span>
                  <div className="flex items-baseline">
                    <span className="text-5xl font-extrabold text-white">{sqMetersCalc}</span>
                    <span className="text-emerald-400 ml-2 font-bold text-xl">m²</span>
                  </div>
                </div>
              </div>

              <button
                onClick={handleSaveDonation}
                disabled={sqMetersCalc <= 0}
                className="w-full bg-emerald-500 hover:bg-emerald-400 disabled:bg-gray-700 disabled:text-gray-500 disabled:shadow-none text-white font-bold py-4 px-4 rounded-xl shadow-[0_0_20px_rgba(16,185,129,0.3)] hover:shadow-[0_0_25px_rgba(16,185,129,0.5)] transition-all duration-200"
              >
                Spende in Datenbank speichern
              </button>

              {donationStatus && (
                <div className={`p-3 rounded-lg text-center text-sm font-medium border ${donationStatus.includes('Fehler') ? 'bg-red-500/10 border-red-500/20 text-red-400' : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400'}`}>
                  {donationStatus}
                </div>
              )}
            </div>
          </div>

          {/* List of Sponsors (moved next to input) */}
          <div className="lg:col-span-2 bg-gray-800/80 backdrop-blur-sm rounded-2xl border border-white/5 shadow-2xl overflow-hidden flex flex-col h-full">
            <div className="px-6 sm:px-8 py-6 border-b border-gray-700 flex flex-col sm:flex-row justify-between items-start sm:items-center bg-gray-800 shrink-0">
              <div>
                <h2 className="text-xl font-semibold text-white">Sponsoren Liste</h2>
                <p className="text-sm text-gray-400 mt-1">Übersicht aller Spenden</p>
              </div>
              <div className="mt-4 sm:mt-0 flex items-center gap-3 flex-wrap">
                <button
                  onClick={exportBankCSV}
                  className="px-4 py-2 bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 rounded-lg inline-flex items-center text-xs font-semibold hover:bg-indigo-500/20 transition-all font-mono"
                >
                  <svg className="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                  BANK CSV
                </button>
                <button
                  onClick={exportCashCSV}
                  className="px-4 py-2 bg-amber-500/10 text-amber-400 border border-amber-500/20 rounded-lg inline-flex items-center text-xs font-semibold hover:bg-amber-500/20 transition-all font-mono"
                >
                  <svg className="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                  CASH CSV
                </button>
                <span className="px-4 py-1.5 bg-gray-900 border border-gray-700 text-gray-300 rounded-full text-sm font-medium shadow-inner">
                  {sponsors.length} Spender
                </span>
              </div>
            </div>

            <div className="overflow-y-auto flex-grow custom-scrollbar max-h-[600px]">
              <table className="w-full text-left border-collapse">
                <thead className="sticky top-0 z-10 bg-gray-900 border-b border-gray-800">
                  <tr className="text-xs uppercase tracking-wider text-gray-500 font-semibold">
                    <th className="px-6 py-4 whitespace-nowrap">Datum</th>
                    <th className="px-6 py-4">Name</th>
                    <th className="px-6 py-4 text-emerald-400">m²</th>
                    <th className="px-6 py-4">Betrag</th>
                    <th className="px-6 py-4 text-right">Zahlungsart</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-800 text-sm">
                  {sponsors.length === 0 ? (
                    <tr>
                      <td colSpan="5" className="px-6 py-12 text-center text-gray-500 bg-gray-800/30">
                        Aktuell befinden sich noch keine Spender in der Datenbank.
                      </td>
                    </tr>
                  ) : (
                    sponsors.map(sponsor => (
                      <tr key={sponsor.id} className="hover:bg-gray-700/30 transition-colors group">
                        <td className="px-6 py-4 text-gray-400 whitespace-nowrap group-hover:text-gray-300">
                          {new Date(sponsor.created_at).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' })}
                        </td>
                        <td className="px-6 py-4 font-medium text-gray-200">
                          {sponsor.full_name}
                          {sponsor.iban === 'CASH' && <span className="ml-2 inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20 uppercase tracking-wide">Bar</span>}
                        </td>
                        <td className="px-6 py-4 text-emerald-400 font-bold text-base">
                          {sponsor.sq_meters}
                        </td>
                        <td className="px-6 py-4 font-mono text-gray-300">
                          {sponsor.iban === 'CASH' && sponsor.total_amount ? String(sponsor.total_amount).replace('.', ',') + '€' : '-'}
                        </td>
                        <td className="px-6 py-4 text-right font-mono text-gray-500">
                          {sponsor.iban === 'CASH' ? 'BAR' : 'BANK'}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div className="mt-8 text-center text-gray-600 text-xs">
          Das Admin Token lautet für diesen Prototyp "admin123".
        </div>
      </div>
    </div>
  );
}
