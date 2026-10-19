import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Agaze Chereta | Tender intelligence', description: 'Evidence-backed tender decisions for Ethiopian marketing and media businesses.' };
export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
