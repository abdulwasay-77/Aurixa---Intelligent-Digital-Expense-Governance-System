import oracledb
from typing import Optional, Any, List, Tuple, Dict
from config import config

class OracleDatabase:
    def __init__(self):
        self.pool = None
        self._initialize_pool()
    
    def _initialize_pool(self):
        try:
            self.pool = oracledb.create_pool(
                user=config.ORACLE_USER,
                password=config.ORACLE_PASSWORD,
                dsn=config.ORACLE_DSN,
                min=2,
                max=10,
                increment=1,
                getmode=oracledb.POOL_GETMODE_WAIT
            )
            print(f"Connection pool created for {config.ORACLE_USER} at {config.ORACLE_DSN}")
        except Exception as e:
            print(f"Failed to create pool: {e}")
            raise
    
    def get_connection(self):
        if not self.pool:
            raise Exception("Connection pool not initialized")
        return self.pool.acquire()
    
    def release_connection(self, connection):
        if connection:
            self.pool.release(connection)
    
    def execute_query(self, query: str, params: Optional[Dict] = None) -> List[Tuple]:
        conn = None
        cursor = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            return cursor.fetchall()
        finally:
            if cursor:
                cursor.close()
            if conn:
                self.release_connection(conn)
    
    def execute_update(self, query: str, params: Optional[Dict] = None) -> int:
        conn = None
        cursor = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            conn.commit()
            return cursor.rowcount
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if cursor:
                cursor.close()
            if conn:
                self.release_connection(conn)
    
    def call_procedure(self, proc_name: str, args: List[Any]) -> None:
        conn = None
        cursor = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            cursor.callproc(proc_name, args)
            conn.commit()
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if cursor:
                cursor.close()
            if conn:
                self.release_connection(conn)
    
    def call_function(self, func_name: str, return_type: Any, args: List[Any]) -> Any:
        conn = None
        cursor = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            result = cursor.callfunc(func_name, return_type, args)
            conn.commit()
            return result
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if cursor:
                cursor.close()
            if conn:
                self.release_connection(conn)
    
    def test_connection(self) -> bool:
        try:
            result = self.execute_query("SELECT 'OK' FROM DUAL")
            return result and result[0][0] == 'OK'
        except Exception:
            return False
    
    def get_version(self) -> str:
        try:
            result = self.execute_query("SELECT version FROM v$instance")
            return result[0][0] if result else "Unknown"
        except Exception:
            return "Unknown"
    
    def close_pool(self):
        if self.pool:
            self.pool.close()
            print("Connection pool closed")

db = OracleDatabase()