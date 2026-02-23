

"use client";

import { useSearchParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { useMemo, Suspense } from "react";

const VisitorCardPage = dynamic(() => import("./[code]/page"), { ssr: false });

function VisitorCardQueryPageInner() {
	const searchParams = useSearchParams();
	const router = useRouter();
	const code = useMemo(() => searchParams.get("id"), [searchParams]);

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
	return <VisitorCardPage params={{ code }} />;
}

export default function VisitorCardQueryPage() {
	return (
		<Suspense fallback={<div className="min-h-screen flex items-center justify-center text-gray-500">Loading...</div>}>
			<VisitorCardQueryPageInner />
		</Suspense>
	);
}
