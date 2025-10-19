"use client"
import { Children, createContext, useContext, useEffect, useState } from "react"
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

    useEffect(() => {
        supabase.auth.getSession().then(({data}) => {
                setUser(data.session?.user ?? null)
            
            setLoading(false)
        })

        const { data : {subscription} ,} = supabase.auth.onAuthStateChange((event, session) => {
            setUser(session?.user ?? null)
        })
return subscription.unsubscribe
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