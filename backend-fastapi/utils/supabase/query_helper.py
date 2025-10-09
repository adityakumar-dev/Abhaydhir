"""
Supabase Query Helper for Raw SQL Execution
This module provides a way to execute raw SQL queries via Supabase RPC functions.

IMPORTANT: Before using this, you MUST create the execute_sql function in your Supabase database.
Run this SQL in Supabase SQL Editor:

-- Create a function to execute raw SQL queries
CREATE OR REPLACE FUNCTION execute_sql(query TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    EXECUTE 'SELECT json_agg(t) FROM (' || query || ') t' INTO result;
    RETURN COALESCE(result, '[]'::JSON);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION execute_sql(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION execute_sql(TEXT) TO service_role;
"""

from utils.supabase.supabase import supabaseAdmin
from typing import List, Dict, Any
import logging

logger = logging.getLogger(__name__)


async def execute_raw_sql(query: str) -> List[Dict[str, Any]]:
    """
    Execute a raw SQL query using Supabase RPC function.
    
    Args:
        query: Raw SQL query string
        
    Returns:
        List of dictionaries containing query results
        
    Raises:
        Exception: If the RPC function doesn't exist or query fails
    """
    try:
        response = supabaseAdmin.rpc("execute_sql", {"query": query}).execute()
        
        if response.data is None:
            return []
            
        # Supabase RPC returns data directly
        return response.data if isinstance(response.data, list) else [response.data]
        
    except Exception as e:
        logger.error(f"Failed to execute SQL query: {str(e)}")
        logger.error(f"Query: {query}")
        
        # Check if it's because the function doesn't exist
        if "function execute_sql" in str(e).lower() and "does not exist" in str(e).lower():
            raise Exception(
                "The 'execute_sql' PostgreSQL function is not created in your Supabase database. "
                "Please run the SQL command from the docstring of this file in your Supabase SQL Editor."
            )
        raise


async def execute_raw_sql_single(query: str) -> Dict[str, Any]:
    """
    Execute a raw SQL query and return a single result.
    
    Args:
        query: Raw SQL query string
        
    Returns:
        Dictionary containing query result (first row)
    """
    results = await execute_raw_sql(query)
    return results[0] if results else {}


# Helper function to safely format SQL values
def sql_escape(value: Any) -> str:
    """
    Escape values for SQL queries to prevent SQL injection.
    Use this cautiously - prefer parameterized queries when possible.
    
    Args:
        value: Value to escape
        
    Returns:
        Escaped string safe for SQL
    """
    if value is None:
        return "NULL"
    elif isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    elif isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, str):
        # Escape single quotes by doubling them
        return f"'{value.replace(chr(39), chr(39) + chr(39))}'"
    else:
        return f"'{str(value).replace(chr(39), chr(39) + chr(39))}'"
