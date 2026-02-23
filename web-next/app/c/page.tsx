
"use client";

import { useSearchParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { useMemo } from "react";

// Dynamically import the VisitorCardPage from /c/[code]/page.tsx
const VisitorCardPage = dynamic(() => import("./[code]/page"), { ssr: false });

export default function VisitorCardQueryPage() {
	const searchParams = useSearchParams();
	const router = useRouter();
	const code = useMemo(() => searchParams.get("id"), [searchParams]);

	// If no code, show a fallback UI or redirect
	if (!code) {
		return (
			<div className="min-h-screen flex items-center justify-center">
				<div className="bg-white p-8 rounded-xl shadow text-center">
					<h2 className="text-lg font-bold mb-2">Missing Visitor Card Code</h2>
					<p className="text-gray-600 mb-4">Please provide a valid <span className="font-mono">id</span> query parameter in the URL.</p>
					<button
						className="bg-violet-600 text-white px-4 py-2 rounded hover:bg-violet-700"
						onClick={() => router.push("/")}
					>
						Return to Home
					</button>
				</div>
			</div>
		);
	}

	// Render the VisitorCardPage with the extracted code
	return <VisitorCardPage params={{ code }} />;
}
