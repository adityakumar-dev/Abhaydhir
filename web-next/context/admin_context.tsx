"use client"
import { createContext, useContext, useEffect, useRef, useState } from "react"
import type { User } from "@supabase/supabase-js"
import { supabase } from "@/lib/supabase"
type UserContextType = {
user : User | null
loading : boolean
}

const UserContext = createContext<UserContextType | undefined>({
    user : null, loading : true
})


export const UserProvider  = ({children} : {children : React.ReactNode}) => {
    const [user, setUser] = useState<User | null>(null)
    const [loading, setLoading] = useState(true)
    const initRef = useRef(false)

    useEffect(() => {
        if (initRef.current) return
        initRef.current = true

        supabase.auth.getSession().then(({data}) => {
            setUser(data.session?.user ?? null)
            setLoading(false)
        })

        const { data : {subscription} } = supabase.auth.onAuthStateChange((_event, session) => {
            const newUser = session?.user ?? null
            setUser(prev => {
                // Only update if user actually changed to avoid cascading re-renders
                if (prev?.id === newUser?.id) return prev
                return newUser
            })
        })
        return () => subscription.unsubscribe()
    }, [])

    return (
        <UserContext.Provider value={{ user, loading }}>
            {children}
        </UserContext.Provider>
    )
}

export const useUser = () => {
    const context = useContext(UserContext)
    if (!context) {
        throw new Error("useUser must be used within a UserProvider")
    }
    return context
}