-- MASTER SCHEMA [2025-12-24]

-- 1. PROFILES
create table profiles (
  id uuid references auth.users not null primary key,
  username text,
  bio text,
  location text,
  avatar_url text,
  updated_at timestamp with time zone
);

-- 2. ITEMS
create table items (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references auth.users not null,
  title text not null,
  description text,
  category text,
  condition text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. MESSAGES
create table messages (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references auth.users not null,
  receiver_id uuid references auth.users not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. STORAGE
-- Bucket: 'images' (Public)

-- 5. REALTIME
alter publication supabase_realtime add table messages;
