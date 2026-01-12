"""
Polymarket Auto Copy Trading Agent
Intelligent BUY + SELL copy trading with position management
"""

import os
import sys
import json
import time
import asyncio
import aiohttp
from datetime import datetime
from typing import Optional, Dict, List, Set
import logging
from pathlib import Path

# Auto-install dependencies if missing
try:
    from web3 import Web3
    from eth_account import Account
    from py_clob_client.client import ClobClient
    from py_clob_client.clob_types import OrderArgs, OrderType
    from telegram import Bot
    from telegram.error import TelegramError
    from colorama import init, Fore, Style, Back
except ImportError:
    print("📦 Installing required packages...")
    os.system(f"{sys.executable} -m pip install web3 eth-account py-clob-client python-telegram-bot colorama aiohttp requests --quiet")
    from web3 import Web3
    from eth_account import Account
    from py_clob_client.client import ClobClient
    from py_clob_client.clob_types import OrderArgs, OrderType
    from telegram import Bot
    from telegram.error import TelegramError
    from colorama import init, Fore, Style, Back

init(autoreset=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class WalletManager:
    """Wallet creation and management"""
    
    @staticmethod
    def print_banner():
        print(f"\n{Fore.CYAN}{Back.BLACK}")
        print("╔════════════════════════════════════════════════════════════════╗")
        print("║                                                                ║")
        print("║        🤖 POLYMARKET AUTO COPY TRADING AGENT v2.0 🤖          ║")
        print("║                                                                ║")
        print("║           BUY + SELL • P&L Tracking • Ultra Fast              ║")
        print("║                                                                ║")
        print("╚════════════════════════════════════════════════════════════════╝")
        print(Style.RESET_ALL)
    
    @staticmethod
    def create_wallet():
        print(f"\n{Fore.YELLOW}🔐 Creating new wallet...")
        account = Account.create()
        
        print(f"{Fore.GREEN}✓ Wallet created!\n")
        print(f"{Fore.CYAN}{'='*70}")
        print(f"{Fore.GREEN}Address:     {Fore.WHITE}{account.address}")
        print(f"{Fore.RED}Private Key: {Fore.WHITE}{account.key.hex()}")
        print(f"{Fore.CYAN}{'='*70}")
        print(f"\n{Fore.RED}⚠️  SAVE THESE SECURELY!")
        print(f"{Fore.YELLOW}   1. Backup private key")
        print(f"{Fore.YELLOW}   2. NEVER share with anyone")
        print(f"{Fore.YELLOW}   3. Import to MetaMask if needed")
        
        return account.address, account.key.hex()


class ConfigWizard:
    """Interactive setup wizard"""
    
    def __init__(self):
        self.config = {}
        self.config_file = 'config.json'
    
    def clear_screen(self):
        os.system('clear' if os.name != 'nt' else 'cls')
    
    def print_step(self, step: int, total: int, title: str):
        print(f"\n{Fore.CYAN}{'='*70}")
        print(f"{Fore.GREEN}[Step {step}/{total}] {Fore.YELLOW}{title}")
        print(f"{Fore.CYAN}{'='*70}{Style.RESET_ALL}\n")
    
    def get_input(self, prompt: str, default: str = "", validator=None) -> str:
        while True:
            user_input = input(f"{Fore.CYAN}{prompt} {Fore.WHITE}").strip() or default
            if validator:
                valid, message = validator(user_input)
                if not valid:
                    print(f"{Fore.RED}❌ {message}")
                    continue
            return user_input
    
    def validate_wallet(self, address: str) -> tuple:
        if not address or not address.startswith('0x') or len(address) != 42:
            return False, "Invalid wallet address"
        return True, ""
    
    def validate_private_key(self, key: str) -> tuple:
        if not key or not key.startswith('0x') or len(key) != 66:
            return False, "Invalid private key"
        try:
            Account.from_key(key)
            return True, ""
        except:
            return False, "Invalid private key format"
    
    def setup_wallet(self) -> tuple:
        self.print_step(1, 8, "💳 Wallet Setup")
        
        print(f"{Fore.WHITE}Choose wallet option:")
        print(f"{Fore.YELLOW}1. Create NEW wallet (recommended)")
        print(f"{Fore.YELLOW}2. Use EXISTING wallet (import MetaMask)")
        
        choice = self.get_input("Enter choice (1 or 2):", "1")
        
        if choice == "1":
            address, private_key = WalletManager.create_wallet()
            input(f"\n{Fore.CYAN}Press ENTER when saved...")
            return address, private_key
        else:
            print(f"\n{Fore.WHITE}Import MetaMask wallet:")
            print(f"{Fore.YELLOW}MetaMask → ⋮ → Account Details → Export Private Key")
            private_key = self.get_input("\nPaste private key:", validator=self.validate_private_key)
            account = Account.from_key(private_key)
            print(f"\n{Fore.GREEN}✓ Imported: {Fore.WHITE}{account.address}")
            return account.address, private_key
    
    def setup_target(self) -> str:
        self.print_step(2, 8, "🎯 Target Wallet Selection")
        
        print(f"{Fore.WHITE}Who do you want to copy?")
        print(f"{Fore.YELLOW}1. Use top performing bot (0x0ea574...) [Recommended]")
        print(f"{Fore.YELLOW}2. Enter custom wallet address")
        
        choice = self.get_input("Enter choice (1 or 2):", "1")
        
        if choice == "1":
            wallet = "0x0ea574f3204c5c9c0cdead90392ea0990f4d17e4"
            print(f"\n{Fore.GREEN}✓ Selected: {Fore.WHITE}{wallet}")
            print(f"{Fore.YELLOW}   Stats: +$500K P&L | 98% Win Rate")
            return wallet
        else:
            return self.get_input("\nEnter wallet address:", validator=self.validate_wallet)
    
    def setup_rpc(self) -> str:
        self.print_step(3, 8, "⚡ RPC Provider Setup")
        
        print(f"{Fore.WHITE}Choose RPC provider:")
        print(f"{Fore.YELLOW}1. Alchemy (FREE - Best speed)")
        print(f"{Fore.YELLOW}2. Infura (FREE)")
        print(f"{Fore.YELLOW}3. Public RPC (FREE but slow)")
        
        choice = self.get_input("Enter choice (1-3):", "1")
        
        if choice == "1":
            print(f"\n{Fore.WHITE}Get free Alchemy RPC:")
            print(f"{Fore.CYAN}https://www.alchemy.com/")
            print(f"{Fore.YELLOW}Create App → Polygon → Copy HTTPS URL")
            
            has_key = self.get_input("\nHave Alchemy URL? (y/n):", "n")
            if has_key.lower() == 'y':
                return self.get_input("Paste URL:")
            print(f"{Fore.YELLOW}Using public RPC (upgrade later for speed)")
            return "https://polygon-rpc.com"
        elif choice == "2":
            print(f"\n{Fore.WHITE}Get Infura: {Fore.CYAN}https://infura.io/")
            has_key = self.get_input("\nHave Infura URL? (y/n):", "n")
            if has_key.lower() == 'y':
                return self.get_input("Paste URL:")
            return "https://polygon-rpc.com"
        else:
            return "https://polygon-rpc.com"
    
    def setup_telegram(self) -> tuple:
        self.print_step(4, 8, "📱 Telegram Notifications")
        
        enable = self.get_input("Enable Telegram? (y/n):", "y")
        if enable.lower() != 'y':
            return "", ""
        
        print(f"\n{Fore.YELLOW}Setup Telegram Bot:")
        print(f"{Fore.WHITE}1. Open Telegram → Search @BotFather")
        print(f"{Fore.WHITE}2. Send /newbot → Follow steps")
        print(f"{Fore.WHITE}3. Copy token")
        
        token = self.get_input("\nBot Token:")
        
        print(f"\n{Fore.YELLOW}Get Chat ID:")
        print(f"{Fore.WHITE}Search @userinfobot → Send /start")
        
        chat_id = self.get_input("Chat ID:")
        
        try:
            bot = Bot(token=token)
            asyncio.run(bot.send_message(chat_id=chat_id, text="🎉 Bot connected!"))
            print(f"{Fore.GREEN}✓ Test message sent!")
        except:
            print(f"{Fore.YELLOW}⚠️  Couldn't send test (will try later)")
        
        return token, chat_id
    
    def setup_params(self) -> dict:
        self.print_step(5, 8, "💰 Trading Parameters")
        
        print(f"{Fore.YELLOW}Copy Percentage (% of balance per trade)")
        print(f"{Fore.WHITE}Conservative: 2-3% | Balanced: 5-7% | Aggressive: 10-15%")
        copy_pct = float(self.get_input("Copy % (1-100):", "5"))
        
        print(f"\n{Fore.YELLOW}Minimum Trade Size (USD)")
        min_trade = float(self.get_input("Min $:", "1"))
        
        print(f"\n{Fore.YELLOW}Maximum Trade Size (USD)")
        max_trade = float(self.get_input("Max $:", "100"))
        
        print(f"\n{Fore.YELLOW}Monitoring Speed (seconds)")
        print(f"{Fore.WHITE}Fast: 2-3s | Normal: 5s")
        interval = float(self.get_input("Interval:", "3"))
        
        return {
            'copy_pct': copy_pct,
            'min_trade': min_trade,
            'max_trade': max_trade,
            'interval': interval
        }
    
    def run_wizard(self) -> dict:
        self.clear_screen()
        WalletManager.print_banner()
        
        print(f"\n{Fore.GREEN}Welcome to Auto-Setup Wizard!")
        print(f"{Fore.WHITE}Setup takes ~5 minutes\n")
        input(f"{Fore.CYAN}Press ENTER to begin...")
        
        # Run setup
        my_address, my_key = self.setup_wallet()
        target = self.setup_target()
        rpc = self.setup_rpc()
        tg_token, tg_chat = self.setup_telegram()
        params = self.setup_params()
        
        # Summary
        self.print_step(6, 8, "📋 Configuration Summary")
        print(f"{Fore.CYAN}Your Wallet:  {Fore.WHITE}{my_address}")
        print(f"{Fore.CYAN}Copying:      {Fore.WHITE}{target}")
        print(f"{Fore.CYAN}Copy %:       {Fore.WHITE}{params['copy_pct']}%")
        print(f"{Fore.CYAN}Range:        {Fore.WHITE}${params['min_trade']}-${params['max_trade']}")
        print(f"{Fore.CYAN}Speed:        {Fore.WHITE}{params['interval']}s")
        
        confirm = self.get_input(f"\n{Fore.GREEN}Confirm? (y/n):", "y")
        if confirm.lower() != 'y':
            return self.run_wizard()
        
        # Save
        config = {
            'MY_ADDRESS': my_address,
            'PRIVATE_KEY': my_key,
            'WALLET_TO_COPY': target,
            'POLYGON_RPC': rpc,
            'TELEGRAM_BOT_TOKEN': tg_token,
            'TELEGRAM_CHAT_ID': tg_chat,
            'COPY_PERCENTAGE': params['copy_pct'],
            'MIN_TRADE_SIZE': params['min_trade'],
            'MAX_TRADE_SIZE': params['max_trade'],
            'MONITOR_INTERVAL': params['interval']
        }
        
        self.print_step(7, 8, "💾 Saving Configuration")
        with open(self.config_file, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"{Fore.GREEN}✓ Saved to {self.config_file}")
        
        # Funding
        self.print_step(8, 8, "💵 Wallet Funding")
        print(f"{Fore.YELLOW}⚠️  Fund your wallet with USDC (Polygon)!")
        print(f"\n{Fore.WHITE}Send USDC to: {Fore.GREEN}{my_address}")
        print(f"{Fore.WHITE}Network: {Fore.GREEN}Polygon")
        print(f"{Fore.WHITE}Recommended: {Fore.GREEN}$50+ for testing")
        
        input(f"\n{Fore.CYAN}Press ENTER when funded...")
        
        return config


class CopyTradingAgent:
    """Main copy trading bot"""
    
    def __init__(self, config: dict):
        self.config = config
        self.my_address = config['MY_ADDRESS']
        self.private_key = config['PRIVATE_KEY']
        self.target_wallet = config['WALLET_TO_COPY']
        self.rpc_url = config['POLYGON_RPC']
        self.copy_pct = config['COPY_PERCENTAGE']
        self.min_trade = config['MIN_TRADE_SIZE']
        self.max_trade = config['MAX_TRADE_SIZE']
        self.interval = config['MONITOR_INTERVAL']
        self.tg_token = config.get('TELEGRAM_BOT_TOKEN', '')
        self.tg_chat = config.get('TELEGRAM_CHAT_ID', '')
        
        # Initialize
        self.w3 = Web3(Web3.HTTPProvider(self.rpc_url))
        self.client = ClobClient("https://clob.polymarket.com", key=self.private_key, chain_id=137)
        self.telegram = Bot(token=self.tg_token) if self.tg_token else None
        
        # Tracking
        self.processed: Set[str] = set()
        self.total_trades = 0
        self.successful = 0
        self.session = None
        self.my_positions = {}
        self.position_cache_time = 0
        
        logger.info("Agent initialized")
    
    async def send_tg(self, msg: str):
        if self.telegram and self.tg_chat:
            try:
                await self.telegram.send_message(chat_id=self.tg_chat, text=msg, parse_mode='HTML')
            except:
                pass
    
    async def get_balance(self) -> float:
        try:
            usdc = Web3.to_checksum_address("0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174")
            abi = [{"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"}]
            contract = self.w3.eth.contract(address=usdc, abi=abi)
            bal = contract.functions.balanceOf(self.my_address).call()
            return bal / 10**6
        except:
            return 0.0
    
    async def update_my_positions(self):
        if time.time() - self.position_cache_time < 30:
            return self.my_positions
        
        try:
            url = f"https://clob.polymarket.com/positions?user={self.my_address}"
            if not self.session:
                self.session = aiohttp.ClientSession()
            
            async with self.session.get(url, timeout=aiohttp.ClientTimeout(total=5)) as r:
                if r.status == 200:
                    positions = await r.json()
                    result = {}
                    for pos in positions:
                        token_id = pos.get('asset_id')
                        if token_id:
                            result[token_id] = {
                                'size': float(pos.get('size', 0)),
                                'avg_price': float(pos.get('average_price', 0))
                            }
                    self.my_positions = result
                    self.position_cache_time = time.time()
        except:
            pass
        
        return self.my_positions
    
    async def fetch_trades(self) -> List[Dict]:
        url = f"https://clob.polymarket.com/trades?maker={self.target_wallet}&limit=10"
        try:
            if not self.session:
                self.session = aiohttp.ClientSession()
            async with self.session.get(url, timeout=aiohttp.ClientTimeout(total=5)) as r:
                if r.status == 200:
                    return await r.json()
        except:
            pass
        return []
    
    async def copy_trade(self, trade: Dict):
        try:
            token_id = trade.get('asset_id')
            side = trade.get('side', 'BUY').upper()
            price = float(trade.get('price', 0.5))
            trade_size = float(trade.get('size', 0))
            
            await self.update_my_positions()
            my_position = self.my_positions.get(token_id, {'size': 0, 'avg_price': 0})
            my_size = my_position['size']
            balance = await self.get_balance()
            
            if side == 'BUY':
                size = min(self.max_trade, max(self.min_trade, balance * self.copy_pct / 100))
                if size < self.min_trade or balance < size:
                    logger.warning(f"Insufficient balance: ${balance:.2f}")
                    return
                
                action_emoji = "🟢"
                action_type = "OPENED" if my_size == 0 else "ADDED TO"
                
            elif side == 'SELL':
                if my_size <= 0:
                    logger.info(f"No position to sell")
                    return
                
                # Estimate sell percentage (simplified)
                sell_pct = min(100, (trade_size / my_size) * 100) if my_size > 0 else 100
                size = (my_size * sell_pct) / 100
                size = max(0.01, min(size, my_size))
                
                action_emoji = "🔴"
                action_type = "CLOSED" if size >= my_size * 0.99 else "REDUCED"
                
                # P&L
                avg_buy = my_position.get('avg_price', 0)
                pnl = (price - avg_buy) * size if avg_buy > 0 else 0
                pnl_pct = ((price - avg_buy) / avg_buy) * 100 if avg_buy > 0 else 0
            else:
                return
            
            # Execute order
            order = OrderArgs(token_id=token_id, price=price, size=size, side=side, fee_rate_bps=0)
            signed = self.client.create_order(order)
            resp = self.client.post_order(signed, OrderType.GTC)
            
            self.successful += 1
            
            # Update local position
            if side == 'BUY':
                new_size = my_size + size
                new_avg = ((my_size * my_position.get('avg_price', 0)) + (size * price)) / new_size if new_size > 0 else price
                self.my_positions[token_id] = {'size': new_size, 'avg_price': new_avg}
            else:
                new_size = max(0, my_size - size)
                self.my_positions[token_id] = {'size': new_size, 'avg_price': my_position.get('avg_price', 0)}
            
            logger.info(f"✓ {side}: ${size:.2f} @ ${price:.4f}")
            
            # Notification
            if side == 'SELL':
                pnl_emoji = "📈" if pnl > 0 else "📉" if pnl < 0 else "➖"
                await self.send_tg(f"""
{action_emoji} <b>{action_type} POSITION!</b>

📉 Sold: ${size:.2f}
💵 Price: ${price:.4f}
📊 Remaining: ${new_size:.2f}

{pnl_emoji} P&L: ${pnl:+.2f} ({pnl_pct:+.1f}%)
💰 Balance: ${balance:.2f}

✅ Success: {self.successful}/{self.total_trades}
                """)
            else:
                await self.send_tg(f"""
{action_emoji} <b>{action_type} POSITION!</b>

📈 Size: ${size:.2f}
💵 Price: ${price:.4f}
📊 Total: ${new_size:.2f}
💰 Balance: ${balance:.2f}

✅ Success: {self.successful}/{self.total_trades}
                """)
            
        except Exception as e:
            logger.error(f"Trade failed: {e}")
    
    async def monitor(self):
        print(f"\n{Fore.GREEN}{'='*70}")
        print(f"{Fore.YELLOW}🚀 COPY TRADING AGENT ACTIVE!")
        print(f"{Fore.GREEN}{'='*70}")
        print(f"{Fore.WHITE}Your Wallet: {Fore.CYAN}{self.my_address}")
        print(f"{Fore.WHITE}Copying:     {Fore.CYAN}{self.target_wallet}")
        print(f"{Fore.WHITE}Copy %:      {Fore.CYAN}{self.copy_pct}%")
        print(f"{Fore.WHITE}Speed:       {Fore.CYAN}{self.interval}s")
        print(f"{Fore.GREEN}{'='*70}\n")
        
        balance = await self.get_balance()
        await self.send_tg(f"""
🤖 <b>BOT STARTED!</b>

💰 Balance: ${balance:.2f}
👤 Copying: {self.target_wallet[:10]}...
📊 Copy %: {self.copy_pct}%

🚀 Monitoring active!
        """)
        
        while True:
            try:
                trades = await self.fetch_trades()
                
                for trade in trades:
                    tid = trade.get('id')
                    if tid not in self.processed:
                        self.processed.add(tid)
                        self.total_trades += 1
                        
                        logger.info(f"⚡ NEW TRADE: {tid}")
                        asyncio.create_task(self.copy_trade(trade))
                
                if len(self.processed) > 1000:
                    self.processed = set(list(self.processed)[-500:])
                
                await asyncio.sleep(self.interval)
                
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                await asyncio.sleep(5)
    
    async def run(self):
        try:
            await self.monitor()
        except KeyboardInterrupt:
            logger.info("Stopped by user")
            await self.send_tg(f"🛑 <b>BOT STOPPED</b>\n\n✅ Success: {self.successful}/{self.total_trades}")
            if self.session:
                await self.session.close()


def main():
    config_file = 'config.json'
    
    if not os.path.exists(config_file):
        wizard = ConfigWizard()
        config = wizard.run_wizard()
        
        print(f"\n{Fore.GREEN}{'='*70}")
        print(f"{Fore.YELLOW}✅ SETUP COMPLETE!")
        print(f"{Fore.GREEN}{'='*70}\n")
        print(f"{Fore.WHITE}Starting bot in 3 seconds...")
        time.sleep(3)
    else:
        with open(config_file, 'r') as f:
            config = json.load(f)
        print(f"\n{Fore.GREEN}✓ Config loaded")
    
    agent = CopyTradingAgent(config)
    
    try:
        asyncio.run(agent.run())
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Shutting down...")
    except Exception as e:
        print(f"\n{Fore.RED}Error: {e}")
        logger.exception("Fatal error")


if __name__ == "__main__":
    main()
