import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';
import './admin-studio.css';

export const metadata: Metadata = { title: 'Englify Quest | Content Studio', description: 'Secure administration for Englify Quest' };

export default function RootLayout({ children }: { children: ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}
