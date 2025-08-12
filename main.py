import os
from pathlib import Path
import telebot
from telebot.types import ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton
from dotenv import load_dotenv

load_dotenv()

API_TOKEN = os.getenv('API_TOKEN')
CHANNEL_ID = os.getenv('CHANNEL_ID')
PRICE_UNIT_GB = float(os.getenv('PRICE_UNIT_GB'))
PRICE_UNIT_MONTH_UNLIMITED = float(os.getenv('PRICE_UNIT_MONTH_UNLIMITED'))
ADMIN_ID = int(os.getenv('ADMIN_ID'))
bot = telebot.TeleBot(API_TOKEN)
my_path = Path(__file__).parent

@bot.message_handler(commands=['start'])
def send_welcome(message):
    if is_admin(message):    
        bot.send_message(message.chat.id, 'Hi Arvin 👋🏻', reply_markup=reply_keyboard())
    else:
        bot.send_message(message.chat.id, '❌This bot is private and you are not allowed to use it❌')

def my_file_balance():
    if not (my_path/'balance.txt').exists():
        with open(my_path/'balance.txt', 'w', encoding='utf-8') as file:
            file.write('0')
            return float(0)
    else:
        with open(my_path/'balance.txt', 'r', encoding='utf-8') as file:
            balance = file.readline().strip()
            return float(balance)
        
#---------------------------------------------------
def update_balance_file(price):
    with open(my_path/'balance.txt', 'w', encoding='utf-8') as file:
        file.write(f"{price:.2f}")
     
def is_admin(message):
    return message.from_user.id == ADMIN_ID

def notify_all(message, text):
    bot.send_message(message.chat.id, text, parse_mode='HTML')
    bot.send_message(CHANNEL_ID, text, parse_mode='HTML')

def reply_keyboard():
    markup = ReplyKeyboardMarkup(resize_keyboard=True)
    markup.row(KeyboardButton('💾 Create'), KeyboardButton('🔄 Reset'), KeyboardButton('✖️ Remove'))
    markup.row(KeyboardButton('💰 Edit Balance'), KeyboardButton('💸 Payment'))
    markup.row(KeyboardButton('❌ Cancel'))
    return markup

def inline_keyboard_type_account(action):
    keyboard = InlineKeyboardMarkup()
    keyboard.row(InlineKeyboardButton('📦 Limited', callback_data=f'Limited|{action}'), InlineKeyboardButton('♾️ Unlimited', callback_data=f'Unlimited|{action}'))
    return keyboard
#---------------------------------------------------
def ask_username(message, next_func, account_type, action):
    if message.text == '❌ Cancel':
        send_welcome(message)
        return
    bot.delete_message(message.chat.id, message.message_id)
    bot.send_message(message.chat.id, '👤 Enter Username:')
    bot.register_next_step_handler(message, lambda m: next_func(m, account_type, action))
    
def ask_volume_or_duration(message, next_func, account_type, username, action):
    if account_type == 'Limited':
        bot.send_message(message.chat.id, '📦 Enter Data Volume (e.g. 10GB):')
    elif account_type == 'Unlimited':
        bot.send_message(message.chat.id, '📅 Enter duration (e.g. 1Month):')
    
    bot.register_next_step_handler(message, lambda m: next_func(m, account_type, username, action))
    
def is_admin_and_valid_command(message):
    return is_admin(message) and (message.text in ['💾 Create', '🔄 Reset', '✖️ Remove'])
#---------------------------------------------------
@bot.message_handler(func=is_admin_and_valid_command)
def type_account_message(message):
    action = (message.text).split()[1]
    bot.send_message(message.chat.id, '👇 Select Account Type 👇', reply_markup=inline_keyboard_type_account(action))
    
@bot.callback_query_handler(func=lambda call: (call.data.startswith('Limited')) or (call.data.startswith('Unlimited')))
def get_username_create(call):
    account_type, action = call.data.split('|')
    ask_username(call.message, process_account_type, account_type, action)

def process_account_type(message, account_type, action):
    if message.text == '❌ Cancel':
        send_welcome(message)
        return
    username = message.text
    next_func = process_data_final
    ask_volume_or_duration(message, next_func, account_type, username, action)

def process_data_final(message, account_type, username, action):
    if message.text == '❌ Cancel':
        send_welcome(message)
        return
    balance = my_file_balance()
    try:
        data = float(message.text)
    except ValueError:
        bot.send_message(message.chat.id, '❌ Invalid input. Please enter a number (e.g. 10).')
        bot.register_next_step_handler(message, lambda m: process_data_final(m, account_type, username, action))
        return

    if account_type == 'Limited':
        price = data * PRICE_UNIT_GB
        traffic = data
        duration = '*'

    elif account_type == 'Unlimited':
        price = data * PRICE_UNIT_MONTH_UNLIMITED
        traffic = '*'
        duration = data

    if (action == 'Create') or (action == 'Reset'):
        balance += price
    elif (action == 'Remove'):
        balance -= price
        
    symb = {
        'Create' : '🆕',
        'Reset' : '🔄️',
        'Remove' : '❌' 
    }
    
    logo = symb[action]
        
    update_balance_file(balance)
    bot.send_message(message.chat.id, '✅The information has been saved and sent to the channel.')
    bot.send_message(
        CHANNEL_ID,
        f"<b>{logo}#{action}\n➖➖➖➖➖➖➖➖➖\n"
        f"👤 Username : <code>{username}</code>\n\n"
        f"🧾 Account Type : {account_type}\n\n"
        f"🔃 Traffic : {traffic} GB\n\n"
        f"📅 Duration : {duration} Month\n\n"
        f"💸 Price : {price} T\n\n"
        f"💰 Current Account : {balance} T</b>\n",
        parse_mode='HTML'
    )
#---------------------------------------------------
@bot.message_handler(func=lambda msg: msg.text == '💰 Edit Balance')
def ask_edit_balance(message):
    if not is_admin(message):
        bot.send_message(message.chat.id, '❌You are not authorized to perform this action.')
        return
    bot.send_message(message.chat.id, '🆕💸Enter the new account amount:')
    bot.register_next_step_handler(message, edit_balance)

def edit_balance(message):
    if message.text == '❌ Cancel':
        send_welcome(message)
        return
    balance = my_file_balance()
    try:
        new_balance = float(message.text)
        balance = new_balance
        update_balance_file(balance)
        notify_all(message, f'✅💰The current account has been updated to <b>{new_balance} T</b>.')
    except ValueError:
        bot.send_message(message.chat.id, '❌Invalid input. Please enter a number (e.g. 10).')
        bot.register_next_step_handler(message, edit_balance)
#---------------------------------------------------
@bot.message_handler(func=lambda msg: msg.text == '💸 Payment')
def ask_payment(message):
    if not is_admin(message):
        bot.send_message(message.chat.id, '❌ You are not authorized to perform this action.') 
        return
    bot.send_message(message.chat.id, '💸Enter the amount paid:')
    bot.register_next_step_handler(message, payment)
    
def payment(message):
    if message.text == '❌ Cancel':
        send_welcome(message)
        return
    balance = my_file_balance()
    try:
        now_payment = float(message.text)
        balance -= now_payment
        update_balance_file(balance)
        notify_all(message, f"💸✅Amount paid <b>{now_payment} T</b>.\n💰Current account is <b>{balance} T</b>.")
    except ValueError:
        bot.send_message(message.chat.id, '❌Invalid input. Please enter a number (e.g. 10).')
        bot.register_next_step_handler(message, payment)
#---------------------------------------------------
@bot.message_handler(func=lambda msg: msg.text == '❌ Cancel')
def cancel(message):
    send_welcome(message)
    
    
bot.infinity_polling()
