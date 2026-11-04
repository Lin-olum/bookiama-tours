
import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import type { ReactNode } from "react";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: "Bokiama Tours & Travel | Discover East Africa",
    template: "%s | Bokiama Tours & Travel",
  },
  description:
    "Discover extraordinary travel experiences across Kenya and Tanzania with Bokiama Tours & Travel. Your next East African journey starts here.",
  keywords: [
    "Kenya tours",
    "Tanzania tours",
    "African safari",
    "East African travel",
    "Bokiama Tours",
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable}`}
    >
      <body>{children}</body>
    </html>
  );
}
