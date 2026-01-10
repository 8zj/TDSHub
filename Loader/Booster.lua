--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

local StrToNumber = tonumber;
local Byte = string.byte;
local Char = string.char;
local Sub = string.sub;
local Subg = string.gsub;
local Rep = string.rep;
local Concat = table.concat;
local Insert = table.insert;
local LDExp = math.ldexp;
local GetFEnv = getfenv or function()
	return _ENV;
end;
local Setmetatable = setmetatable;
local PCall = pcall;
local Select = select;
local Unpack = unpack or table.unpack;
local ToNumber = tonumber;
local function VMCall(ByteString, vmenv, ...)
	local DIP = 1;
	local repeatNext;
	ByteString = Subg(Sub(ByteString, 5), "..", function(byte)
		if (Byte(byte, 2) == 81) then
			repeatNext = StrToNumber(Sub(byte, 1, 1));
			return "";
		else
			local a = Char(StrToNumber(byte, 16));
			if repeatNext then
				local b = Rep(a, repeatNext);
				repeatNext = nil;
				return b;
			else
				return a;
			end
		end
	end);
	local function gBit(Bit, Start, End)
		if End then
			local Res = (Bit / (2 ^ (Start - 1))) % (2 ^ (((End - 1) - (Start - 1)) + 1));
			return Res - (Res % 1);
		else
			local Plc = 2 ^ (Start - 1);
			return (((Bit % (Plc + Plc)) >= Plc) and 1) or 0;
		end
	end
	local function gBits8()
		local a = Byte(ByteString, DIP, DIP);
		DIP = DIP + 1;
		return a;
	end
	local function gBits16()
		local a, b = Byte(ByteString, DIP, DIP + 2);
		DIP = DIP + 2;
		return (b * 256) + a;
	end
	local function gBits32()
		local a, b, c, d = Byte(ByteString, DIP, DIP + 3);
		DIP = DIP + 4;
		return (d * 16777216) + (c * 65536) + (b * 256) + a;
	end
	local function gFloat()
		local Left = gBits32();
		local Right = gBits32();
		local IsNormal = 1;
		local Mantissa = (gBit(Right, 1, 20) * (2 ^ 32)) + Left;
		local Exponent = gBit(Right, 21, 31);
		local Sign = ((gBit(Right, 32) == 1) and -1) or 1;
		if (Exponent == 0) then
			if (Mantissa == 0) then
				return Sign * 0;
			else
				Exponent = 1;
				IsNormal = 0;
			end
		elseif (Exponent == 2047) then
			return ((Mantissa == 0) and (Sign * (1 / 0))) or (Sign * NaN);
		end
		return LDExp(Sign, Exponent - 1023) * (IsNormal + (Mantissa / (2 ^ 52)));
	end
	local function gString(Len)
		local Str;
		if not Len then
			Len = gBits32();
			if (Len == 0) then
				return "";
			end
		end
		Str = Sub(ByteString, DIP, (DIP + Len) - 1);
		DIP = DIP + Len;
		local FStr = {};
		for Idx = 1, #Str do
			FStr[Idx] = Char(Byte(Sub(Str, Idx, Idx)));
		end
		return Concat(FStr);
	end
	local gInt = gBits32;
	local function _R(...)
		return {...}, Select("#", ...);
	end
	local function Deserialize()
		local Instrs = {};
		local Functions = {};
		local Lines = {};
		local Chunk = {Instrs,Functions,nil,Lines};
		local ConstCount = gBits32();
		local Consts = {};
		for Idx = 1, ConstCount do
			local Type = gBits8();
			local Cons;
			if (Type == 1) then
				Cons = gBits8() ~= 0;
			elseif (Type == 2) then
				Cons = gFloat();
			elseif (Type == 3) then
				Cons = gString();
			end
			Consts[Idx] = Cons;
		end
		Chunk[3] = gBits8();
		for Idx = 1, gBits32() do
			local Descriptor = gBits8();
			if (gBit(Descriptor, 1, 1) == 0) then
				local Type = gBit(Descriptor, 2, 3);
				local Mask = gBit(Descriptor, 4, 6);
				local Inst = {gBits16(),gBits16(),nil,nil};
				if (Type == 0) then
					Inst[3] = gBits16();
					Inst[4] = gBits16();
				elseif (Type == 1) then
					Inst[3] = gBits32();
				elseif (Type == 2) then
					Inst[3] = gBits32() - (2 ^ 16);
				elseif (Type == 3) then
					Inst[3] = gBits32() - (2 ^ 16);
					Inst[4] = gBits16();
				end
				if (gBit(Mask, 1, 1) == 1) then
					Inst[2] = Consts[Inst[2]];
				end
				if (gBit(Mask, 2, 2) == 1) then
					Inst[3] = Consts[Inst[3]];
				end
				if (gBit(Mask, 3, 3) == 1) then
					Inst[4] = Consts[Inst[4]];
				end
				Instrs[Idx] = Inst;
			end
		end
		for Idx = 1, gBits32() do
			Functions[Idx - 1] = Deserialize();
		end
		return Chunk;
	end
	local function Wrap(Chunk, Upvalues, Env)
		local Instr = Chunk[1];
		local Proto = Chunk[2];
		local Params = Chunk[3];
		return function(...)
			local Instr = Instr;
			local Proto = Proto;
			local Params = Params;
			local _R = _R;
			local VIP = 1;
			local Top = -1;
			local Vararg = {};
			local Args = {...};
			local PCount = Select("#", ...) - 1;
			local Lupvals = {};
			local Stk = {};
			for Idx = 0, PCount do
				if (Idx >= Params) then
					Vararg[Idx - Params] = Args[Idx + 1];
				else
					Stk[Idx] = Args[Idx + 1];
				end
			end
			local Varargsz = (PCount - Params) + 1;
			local Inst;
			local Enum;
			while true do
				Inst = Instr[VIP];
				Enum = Inst[1];
				if (Enum <= 97) then
					if (Enum <= 48) then
						if (Enum <= 23) then
							if (Enum <= 11) then
								if (Enum <= 5) then
									if (Enum <= 2) then
										if (Enum <= 0) then
											local A = Inst[2];
											local Results, Limit = _R(Stk[A]());
											Top = (Limit + A) - 1;
											local Edx = 0;
											for Idx = A, Top do
												Edx = Edx + 1;
												Stk[Idx] = Results[Edx];
											end
										elseif (Enum == 1) then
											local B;
											local A;
											Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
											VIP = VIP + 1;
											Inst = Instr[VIP];
											Stk[Inst[2]]();
											VIP = VIP + 1;
											Inst = Instr[VIP];
											Stk[Inst[2]] = Env[Inst[3]];
											VIP = VIP + 1;
											Inst = Instr[VIP];
											A = Inst[2];
											B = Stk[Inst[3]];
											Stk[A + 1] = B;
											Stk[A] = B[Inst[4]];
											VIP = VIP + 1;
											Inst = Instr[VIP];
											A = Inst[2];
											Stk[A] = Stk[A](Stk[A + 1]);
											VIP = VIP + 1;
											Inst = Instr[VIP];
											if Stk[Inst[2]] then
												VIP = VIP + 1;
											else
												VIP = Inst[3];
											end
										else
											Stk[Inst[2]] = Inst[3] ~= 0;
											VIP = VIP + 1;
										end
									elseif (Enum <= 3) then
										local K;
										local B;
										local A;
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										B = Inst[3];
										K = Stk[B];
										for Idx = B + 1, Inst[4] do
											K = K .. Stk[Idx];
										end
										Stk[Inst[2]] = K;
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3] ~= 0;
										VIP = VIP + 1;
										Inst = Instr[VIP];
										do
											return Stk[Inst[2]];
										end
									elseif (Enum == 4) then
										local A;
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
										VIP = VIP + 1;
										Inst = Instr[VIP];
										for Idx = Inst[2], Inst[3] do
											Stk[Idx] = nil;
										end
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										if (Stk[Inst[2]] == Inst[4]) then
											VIP = VIP + 1;
										else
											VIP = Inst[3];
										end
									elseif (Stk[Inst[2]] ~= Inst[4]) then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								elseif (Enum <= 8) then
									if (Enum <= 6) then
										local B;
										local A;
										Stk[Inst[2]] = {};
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = {};
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Upvalues[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										B = Stk[Inst[3]];
										Stk[A + 1] = B;
										Stk[A] = B[Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
										VIP = VIP + 1;
										Inst = Instr[VIP];
										B = Stk[Inst[4]];
										if B then
											VIP = VIP + 1;
										else
											Stk[Inst[2]] = B;
											VIP = Inst[3];
										end
									elseif (Enum > 7) then
										do
											return Stk[Inst[2]]();
										end
									else
										local A;
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Upvalues[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
									end
								elseif (Enum <= 9) then
									local A = Inst[2];
									local Step = Stk[A + 2];
									local Index = Stk[A] + Step;
									Stk[A] = Index;
									if (Step > 0) then
										if (Index <= Stk[A + 1]) then
											VIP = Inst[3];
											Stk[A + 3] = Index;
										end
									elseif (Index >= Stk[A + 1]) then
										VIP = Inst[3];
										Stk[A + 3] = Index;
									end
								elseif (Enum == 10) then
									local B;
									local A;
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									VIP = Inst[3];
								else
									local A;
									A = Inst[2];
									Stk[A] = Stk[A]();
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]] + Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Upvalues[Inst[3]] = Stk[Inst[2]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]] + Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Upvalues[Inst[3]] = Stk[Inst[2]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = #Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if (Inst[2] < Stk[Inst[4]]) then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								end
							elseif (Enum <= 17) then
								if (Enum <= 14) then
									if (Enum <= 12) then
										local B;
										local A;
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										B = Stk[Inst[3]];
										Stk[A + 1] = B;
										Stk[A] = B[Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									elseif (Enum > 13) then
										local A = Inst[2];
										local B = Stk[Inst[3]];
										Stk[A + 1] = B;
										Stk[A] = B[Inst[4]];
									else
										local A;
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Upvalues[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A]();
										VIP = VIP + 1;
										Inst = Instr[VIP];
										if (Stk[Inst[2]] <= Stk[Inst[4]]) then
											VIP = VIP + 1;
										else
											VIP = Inst[3];
										end
									end
								elseif (Enum <= 15) then
									local A;
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A]();
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								elseif (Enum == 16) then
									local T;
									local K;
									local B;
									local A;
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Inst[3];
									K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Inst[3];
									K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									T = Stk[A];
									B = Inst[3];
									for Idx = 1, B do
										T[Idx] = Stk[A + Idx];
									end
								else
									Stk[Inst[2]]();
								end
							elseif (Enum <= 20) then
								if (Enum <= 18) then
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
								elseif (Enum == 19) then
									local A;
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]]();
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return;
									end
								else
									local Edx;
									local Results;
									local B;
									local A;
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Results = {Stk[A](Stk[A + 1])};
									Edx = 0;
									for Idx = A, Inst[4] do
										Edx = Edx + 1;
										Stk[Idx] = Results[Edx];
									end
									VIP = VIP + 1;
									Inst = Instr[VIP];
									VIP = Inst[3];
								end
							elseif (Enum <= 21) then
								local A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							elseif (Enum == 22) then
								local B;
								local A;
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							else
								local B = Stk[Inst[4]];
								if not B then
									VIP = VIP + 1;
								else
									Stk[Inst[2]] = B;
									VIP = Inst[3];
								end
							end
						elseif (Enum <= 35) then
							if (Enum <= 29) then
								if (Enum <= 26) then
									if (Enum <= 24) then
										local A;
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Upvalues[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A]();
										VIP = VIP + 1;
										Inst = Instr[VIP];
										if (Stk[Inst[2]] <= Stk[Inst[4]]) then
											VIP = VIP + 1;
										else
											VIP = Inst[3];
										end
									elseif (Enum == 25) then
										local A;
										Stk[Inst[2]]();
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										VIP = Inst[3];
									else
										local B;
										local A;
										A = Inst[2];
										B = Stk[Inst[3]];
										Stk[A + 1] = B;
										Stk[A] = B[Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										do
											return Stk[A](Unpack(Stk, A + 1, Inst[3]));
										end
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										do
											return Unpack(Stk, A, Top);
										end
										VIP = VIP + 1;
										Inst = Instr[VIP];
										do
											return;
										end
									end
								elseif (Enum <= 27) then
									local A = Inst[2];
									local T = Stk[A];
									for Idx = A + 1, Top do
										Insert(T, Stk[Idx]);
									end
								elseif (Enum > 28) then
									local B;
									local A;
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return;
									end
								else
									local A = Inst[2];
									local Cls = {};
									for Idx = 1, #Lupvals do
										local List = Lupvals[Idx];
										for Idz = 0, #List do
											local Upv = List[Idz];
											local NStk = Upv[1];
											local DIP = Upv[2];
											if ((NStk == Stk) and (DIP >= A)) then
												Cls[DIP] = NStk[DIP];
												Upv[1] = Cls;
											end
										end
									end
								end
							elseif (Enum <= 32) then
								if (Enum <= 30) then
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									for Idx = Inst[2], Inst[3] do
										Stk[Idx] = nil;
									end
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								elseif (Enum == 31) then
									local B;
									local A;
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if not Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								else
									local A;
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								end
							elseif (Enum <= 33) then
								local B;
								local A;
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Stk[Inst[4]];
								if B then
									VIP = VIP + 1;
								else
									Stk[Inst[2]] = B;
									VIP = Inst[3];
								end
							elseif (Enum > 34) then
								local A;
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if (Stk[Inst[2]] <= Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local B;
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							end
						elseif (Enum <= 41) then
							if (Enum <= 38) then
								if (Enum <= 36) then
									local A = Inst[2];
									do
										return Unpack(Stk, A, Top);
									end
								elseif (Enum == 37) then
									Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								else
									local Step;
									local Index;
									local K;
									local B;
									local A;
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Inst[3];
									K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Index = Stk[A];
									Step = Stk[A + 2];
									if (Step > 0) then
										if (Index > Stk[A + 1]) then
											VIP = Inst[3];
										else
											Stk[A + 3] = Index;
										end
									elseif (Index < Stk[A + 1]) then
										VIP = Inst[3];
									else
										Stk[A + 3] = Index;
									end
								end
							elseif (Enum <= 39) then
								local B;
								local A;
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum == 40) then
								local K;
								local B;
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								do
									return;
								end
							end
						elseif (Enum <= 44) then
							if (Enum <= 42) then
								local B;
								local A;
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
							elseif (Enum > 43) then
								local T;
								local A;
								local K;
								local B;
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								T = Stk[A];
								B = Inst[3];
								for Idx = 1, B do
									T[Idx] = Stk[A + Idx];
								end
							else
								local A = Inst[2];
								local T = Stk[A];
								local B = Inst[3];
								for Idx = 1, B do
									T[Idx] = Stk[A + Idx];
								end
							end
						elseif (Enum <= 46) then
							if (Enum > 45) then
								local B;
								local A;
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								do
									return Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								do
									return Unpack(Stk, A, Top);
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							else
								local B;
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Stk[Inst[4]];
								if not B then
									VIP = VIP + 1;
								else
									Stk[Inst[2]] = B;
									VIP = Inst[3];
								end
							end
						elseif (Enum == 47) then
							local Results;
							local Edx;
							local Results, Limit;
							local B;
							local A;
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results, Limit = _R(Stk[A](Stk[A + 1]));
							Top = (Limit + A) - 1;
							Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results = {Stk[A](Unpack(Stk, A + 1, Top))};
							Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							VIP = Inst[3];
						elseif (Inst[2] < Stk[Inst[4]]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 72) then
						if (Enum <= 60) then
							if (Enum <= 54) then
								if (Enum <= 51) then
									if (Enum <= 49) then
										local A;
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
										VIP = VIP + 1;
										Inst = Instr[VIP];
										if (Stk[Inst[2]] == Stk[Inst[4]]) then
											VIP = VIP + 1;
										else
											VIP = Inst[3];
										end
									elseif (Enum == 50) then
										local Edx;
										local Results, Limit;
										local K;
										local B;
										local A;
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										B = Inst[3];
										K = Stk[B];
										for Idx = B + 1, Inst[4] do
											K = K .. Stk[Idx];
										end
										Stk[Inst[2]] = K;
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Upvalues[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Env[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
										Top = (Limit + A) - 1;
										Edx = 0;
										for Idx = A, Top do
											Edx = Edx + 1;
											Stk[Idx] = Results[Edx];
										end
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Unpack(Stk, A + 1, Top));
										VIP = VIP + 1;
										Inst = Instr[VIP];
										for Idx = Inst[2], Inst[3] do
											Stk[Idx] = nil;
										end
									else
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = {};
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = {};
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = {};
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]][Inst[3]] = Inst[4];
									end
								elseif (Enum <= 52) then
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								elseif (Enum == 53) then
									local A;
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = #Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								else
									local B;
									local A;
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								end
							elseif (Enum <= 57) then
								if (Enum <= 55) then
									local K;
									local B;
									local A;
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Inst[3];
									K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3] ~= 0;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return Stk[Inst[2]];
									end
								elseif (Enum == 56) then
									local A;
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if (Inst[2] < Stk[Inst[4]]) then
										VIP = Inst[3];
									else
										VIP = VIP + 1;
									end
								else
									local A;
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]]();
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return;
									end
								end
							elseif (Enum <= 58) then
								local Edx;
								local Results, Limit;
								local B;
								local A;
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
								Top = (Limit + A) - 1;
								Edx = 0;
								for Idx = A, Top do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Top));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
							elseif (Enum == 59) then
								local B;
								local A;
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Stk[Inst[4]];
								if B then
									VIP = VIP + 1;
								else
									Stk[Inst[2]] = B;
									VIP = Inst[3];
								end
							else
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							end
						elseif (Enum <= 66) then
							if (Enum <= 63) then
								if (Enum <= 61) then
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
								elseif (Enum == 62) then
									local Edx;
									local Results, Limit;
									local B;
									local A;
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Results, Limit = _R(Stk[A]());
									Top = (Limit + A) - 1;
									Edx = 0;
									for Idx = A, Top do
										Edx = Edx + 1;
										Stk[Idx] = Results[Edx];
									end
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Top));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return;
									end
								else
									local B;
									local A;
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
							elseif (Enum <= 64) then
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum > 65) then
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Top));
							else
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if (Stk[Inst[2]] == Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							end
						elseif (Enum <= 69) then
							if (Enum <= 67) then
								Stk[Inst[2]] = Stk[Inst[3]] - Stk[Inst[4]];
							elseif (Enum > 68) then
								local K;
								local B;
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Upvalues[Inst[3]] = Stk[Inst[2]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Upvalues[Inst[3]] = Stk[Inst[2]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Upvalues[Inst[3]] = Stk[Inst[2]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Upvalues[Inst[3]] = Stk[Inst[2]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							else
								local A = Inst[2];
								local T = Stk[A];
								for Idx = A + 1, Inst[3] do
									Insert(T, Stk[Idx]);
								end
							end
						elseif (Enum <= 70) then
							local B;
							local A;
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = {};
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							do
								return Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							do
								return Unpack(Stk, A, Top);
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							do
								return;
							end
						elseif (Enum > 71) then
							local Edx;
							local Results;
							local A;
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
							Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							local B;
							local A;
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						end
					elseif (Enum <= 84) then
						if (Enum <= 78) then
							if (Enum <= 75) then
								if (Enum <= 73) then
									local A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
								elseif (Enum > 74) then
									Stk[Inst[2]] = {};
								else
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
								end
							elseif (Enum <= 76) then
								local B;
								local A;
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							elseif (Enum == 77) then
								local B;
								local A;
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								do
									return Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								do
									return Unpack(Stk, A, Top);
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							else
								local A;
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if (Stk[Inst[2]] <= Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							end
						elseif (Enum <= 81) then
							if (Enum <= 79) then
								local B;
								local T;
								local A;
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								T = Stk[A];
								B = Inst[3];
								for Idx = 1, B do
									T[Idx] = Stk[A + Idx];
								end
							elseif (Enum > 80) then
								local A = Inst[2];
								local Results, Limit = _R(Stk[A](Stk[A + 1]));
								Top = (Limit + A) - 1;
								local Edx = 0;
								for Idx = A, Top do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								Stk[Inst[2]] = Stk[Inst[3]];
							end
						elseif (Enum <= 82) then
							VIP = Inst[3];
						elseif (Enum == 83) then
							local B;
							local A;
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = {};
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						else
							local B;
							local A;
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							do
								return;
							end
						end
					elseif (Enum <= 90) then
						if (Enum <= 87) then
							if (Enum <= 85) then
								Stk[Inst[2]] = Env[Inst[3]];
							elseif (Enum == 86) then
								for Idx = Inst[2], Inst[3] do
									Stk[Idx] = nil;
								end
							else
								local K;
								local B;
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3] ~= 0;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return Stk[Inst[2]];
								end
							end
						elseif (Enum <= 88) then
							Stk[Inst[2]] = Stk[Inst[3]] + Stk[Inst[4]];
						elseif (Enum == 89) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Inst[4];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Inst[4];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
						elseif (Stk[Inst[2]] == Stk[Inst[4]]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 93) then
						if (Enum <= 91) then
							local A;
							local K;
							local B;
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							B = Inst[3];
							K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						elseif (Enum == 92) then
							Stk[Inst[2]][Stk[Inst[3]]] = Inst[4];
						else
							local A = Inst[2];
							Stk[A](Stk[A + 1]);
						end
					elseif (Enum <= 95) then
						if (Enum > 94) then
							local K;
							local B;
							local A;
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							B = Inst[3];
							K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]] * Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
						else
							Stk[Inst[2]] = Stk[Inst[3]] + Inst[4];
						end
					elseif (Enum > 96) then
						local A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Top));
					else
						local A;
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]] * Inst[4];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]] * Inst[4];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]] * Inst[4];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						VIP = Inst[3];
					end
				elseif (Enum <= 146) then
					if (Enum <= 121) then
						if (Enum <= 109) then
							if (Enum <= 103) then
								if (Enum <= 100) then
									if (Enum <= 98) then
										local B;
										local A;
										A = Inst[2];
										B = Stk[Inst[3]];
										Stk[A + 1] = B;
										Stk[A] = B[Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3] ~= 0;
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
										VIP = VIP + 1;
										Inst = Instr[VIP];
										if Stk[Inst[2]] then
											VIP = VIP + 1;
										else
											VIP = Inst[3];
										end
									elseif (Enum > 99) then
										Stk[Inst[2]] = Stk[Inst[3]] * Inst[4];
									else
										local A;
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Inst[3];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										A = Inst[2];
										Stk[A](Stk[A + 1]);
										VIP = VIP + 1;
										Inst = Instr[VIP];
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
										VIP = VIP + 1;
										Inst = Instr[VIP];
										if (Stk[Inst[2]] == Inst[4]) then
											VIP = VIP + 1;
										else
											VIP = Inst[3];
										end
									end
								elseif (Enum <= 101) then
									local K;
									local B;
									local A;
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Inst[3];
									K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3] ~= 0;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return Stk[Inst[2]];
									end
								elseif (Enum > 102) then
									Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
								else
									local T;
									local B;
									local A;
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A]();
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = {};
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Inst[4];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									T = Stk[A];
									B = Inst[3];
									for Idx = 1, B do
										T[Idx] = Stk[A + Idx];
									end
								end
							elseif (Enum <= 106) then
								if (Enum <= 104) then
									Stk[Inst[2]][Inst[3]] = Inst[4];
								elseif (Enum > 105) then
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								else
									local B;
									local A;
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								end
							elseif (Enum <= 107) then
								local B;
								local A;
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum > 108) then
								local A;
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								VIP = Inst[3];
							else
								Stk[Inst[2]][Stk[Inst[3]]] = Stk[Inst[4]];
							end
						elseif (Enum <= 115) then
							if (Enum <= 112) then
								if (Enum <= 110) then
									local B;
									local A;
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Stk[Inst[4]];
									if B then
										VIP = VIP + 1;
									else
										Stk[Inst[2]] = B;
										VIP = Inst[3];
									end
								elseif (Enum == 111) then
									local B;
									local A;
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								else
									local K;
									local B;
									local A;
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Inst[3];
									K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return;
									end
								end
							elseif (Enum <= 113) then
								local B;
								local A;
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum == 114) then
								local B;
								local A;
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local A = Inst[2];
								local Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
								Top = (Limit + A) - 1;
								local Edx = 0;
								for Idx = A, Top do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum <= 118) then
							if (Enum <= 116) then
								local B;
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum > 117) then
								local T;
								local A;
								local K;
								local B;
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								T = Stk[A];
								B = Inst[3];
								for Idx = 1, B do
									T[Idx] = Stk[A + Idx];
								end
							else
								local B;
								local A;
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							end
						elseif (Enum <= 119) then
							Stk[Inst[2]] = Inst[3];
						elseif (Enum == 120) then
							if (Stk[Inst[2]] <= Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							local Edx;
							local Results, Limit;
							local B;
							local A;
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
							Top = (Limit + A) - 1;
							Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Top));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						end
					elseif (Enum <= 133) then
						if (Enum <= 127) then
							if (Enum <= 124) then
								if (Enum <= 122) then
									local A;
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]]();
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]]();
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return;
									end
								elseif (Enum == 123) then
									local B;
									local A;
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Upvalues[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									do
										return;
									end
								else
									do
										return Stk[Inst[2]];
									end
								end
							elseif (Enum <= 125) then
								if (Stk[Inst[2]] == Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum == 126) then
								local A = Inst[2];
								local C = Inst[4];
								local CB = A + 2;
								local Result = {Stk[A](Stk[A + 1], Stk[CB])};
								for Idx = 1, C do
									Stk[CB + Idx] = Result[Idx];
								end
								local R = Result[1];
								if R then
									Stk[CB] = R;
									VIP = Inst[3];
								else
									VIP = VIP + 1;
								end
							else
								local A;
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Inst[4];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = #Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if (Stk[Inst[2]] <= Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							end
						elseif (Enum <= 130) then
							if (Enum <= 128) then
								local K;
								local B;
								local A;
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							elseif (Enum == 129) then
								local A;
								local K;
								local B;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								VIP = Inst[3];
							else
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
							end
						elseif (Enum <= 131) then
							local Edx;
							local Results;
							local A;
							A = Inst[2];
							Stk[A] = Stk[A]();
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results = {Stk[A](Stk[A + 1])};
							Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 132) then
							local B;
							local A;
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							B = Stk[Inst[4]];
							if not B then
								VIP = VIP + 1;
							else
								Stk[Inst[2]] = B;
								VIP = Inst[3];
							end
						else
							local B;
							local A;
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum <= 139) then
						if (Enum <= 136) then
							if (Enum <= 134) then
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							elseif (Enum > 135) then
								Stk[Inst[2]] = Upvalues[Inst[3]];
							else
								Upvalues[Inst[3]] = Stk[Inst[2]];
							end
						elseif (Enum <= 137) then
							local B;
							local A;
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						elseif (Enum > 138) then
							Stk[Inst[2]] = Inst[3] ~= 0;
						else
							local B = Inst[3];
							local K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
						end
					elseif (Enum <= 142) then
						if (Enum <= 140) then
							local B;
							local A;
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum == 141) then
							local A;
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							do
								return Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							do
								return Unpack(Stk, A, Top);
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							do
								return;
							end
						else
							local A = Inst[2];
							local Results = {Stk[A](Stk[A + 1])};
							local Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						end
					elseif (Enum <= 144) then
						if (Enum == 143) then
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						else
							local A;
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum > 145) then
						local A;
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						do
							return Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						do
							return Unpack(Stk, A, Top);
						end
					else
						local B;
						local A;
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Stk[A + 1]);
					end
				elseif (Enum <= 170) then
					if (Enum <= 158) then
						if (Enum <= 152) then
							if (Enum <= 149) then
								if (Enum <= 147) then
									local B;
									local A;
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								elseif (Enum == 148) then
									local B;
									local A;
									A = Inst[2];
									B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Stk[Inst[4]];
									if B then
										VIP = VIP + 1;
									else
										Stk[Inst[2]] = B;
										VIP = Inst[3];
									end
								else
									local K;
									local B;
									local A;
									Stk[Inst[2]] = Inst[3];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Env[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									Stk[Inst[2]] = Stk[Inst[3]];
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
									VIP = VIP + 1;
									Inst = Instr[VIP];
									B = Inst[3];
									K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
									VIP = VIP + 1;
									Inst = Instr[VIP];
									A = Inst[2];
									Stk[A](Stk[A + 1]);
								end
							elseif (Enum <= 150) then
								Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
							elseif (Enum > 151) then
								local B;
								local A;
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = {};
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								do
									return Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								do
									return Unpack(Stk, A, Top);
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							else
								local A = Inst[2];
								do
									return Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
							end
						elseif (Enum <= 155) then
							if (Enum <= 153) then
								local A;
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A]();
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if (Stk[Inst[2]] <= Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum == 154) then
								local K;
								local B;
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3] ~= 0;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return Stk[Inst[2]];
								end
							else
								local K;
								local B;
								local A;
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								B = Inst[3];
								K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							end
						elseif (Enum <= 156) then
							local Results;
							local Edx;
							local Results, Limit;
							local A;
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results, Limit = _R(Stk[A](Stk[A + 1]));
							Top = (Limit + A) - 1;
							Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results = {Stk[A](Unpack(Stk, A + 1, Top))};
							Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							VIP = Inst[3];
						elseif (Enum == 157) then
							local B = Stk[Inst[4]];
							if B then
								VIP = VIP + 1;
							else
								Stk[Inst[2]] = B;
								VIP = Inst[3];
							end
						else
							local A = Inst[2];
							Stk[A] = Stk[A]();
						end
					elseif (Enum <= 164) then
						if (Enum <= 161) then
							if (Enum <= 159) then
								local B;
								local A;
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if not Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum == 160) then
								local B;
								local A;
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								do
									return;
								end
							else
								local A = Inst[2];
								do
									return Unpack(Stk, A, A + Inst[3]);
								end
							end
						elseif (Enum <= 162) then
							local A;
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]]();
							VIP = VIP + 1;
							Inst = Instr[VIP];
							do
								return;
							end
						elseif (Enum == 163) then
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
						else
							local Results;
							local Edx;
							local Results, Limit;
							local B;
							local A;
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results, Limit = _R(Stk[A](Stk[A + 1]));
							Top = (Limit + A) - 1;
							Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Results = {Stk[A](Unpack(Stk, A + 1, Top))};
							Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
							VIP = VIP + 1;
							Inst = Instr[VIP];
							VIP = Inst[3];
						end
					elseif (Enum <= 167) then
						if (Enum <= 165) then
							local B;
							local A;
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 166) then
							local K;
							local B;
							local A;
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							B = Inst[3];
							K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							VIP = Inst[3];
						elseif (Inst[2] <= Stk[Inst[4]]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 168) then
						local B;
						local A;
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3] ~= 0;
						VIP = VIP + 1;
						Inst = Instr[VIP];
						for Idx = Inst[2], Inst[3] do
							Stk[Idx] = nil;
						end
					elseif (Enum == 169) then
						local A;
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = #Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						do
							return Stk[Inst[2]];
						end
						VIP = VIP + 1;
						Inst = Instr[VIP];
						do
							return;
						end
					else
						local A = Inst[2];
						Top = (A + Varargsz) - 1;
						for Idx = A, Top do
							local VA = Vararg[Idx - A];
							Stk[Idx] = VA;
						end
					end
				elseif (Enum <= 182) then
					if (Enum <= 176) then
						if (Enum <= 173) then
							if (Enum <= 171) then
								local B;
								local A;
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A](Stk[A + 1]);
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Inst[3];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum == 172) then
								local Edx;
								local Results;
								local A;
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Env[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Upvalues[Inst[3]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								VIP = VIP + 1;
								Inst = Instr[VIP];
								A = Inst[2];
								Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
								Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
								VIP = VIP + 1;
								Inst = Instr[VIP];
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Top))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum <= 174) then
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum == 175) then
							local A;
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3] ~= 0;
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3] ~= 0;
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3] ~= 0;
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3] ~= 0;
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = {};
						else
							local A;
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Env[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
						end
					elseif (Enum <= 179) then
						if (Enum <= 177) then
							local B;
							local A;
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum == 178) then
							local B;
							local A;
							A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							Stk[Inst[2]] = Stk[Inst[3]] * Stk[Inst[4]];
						end
					elseif (Enum <= 180) then
						local A = Inst[2];
						local Index = Stk[A];
						local Step = Stk[A + 2];
						if (Step > 0) then
							if (Index > Stk[A + 1]) then
								VIP = Inst[3];
							else
								Stk[A + 3] = Index;
							end
						elseif (Index < Stk[A + 1]) then
							VIP = Inst[3];
						else
							Stk[A + 3] = Index;
						end
					elseif (Enum > 181) then
						local Edx;
						local Results, Limit;
						local K;
						local B;
						local A;
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						B = Inst[3];
						K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
						Top = (Limit + A) - 1;
						Edx = 0;
						for Idx = A, Top do
							Edx = Edx + 1;
							Stk[Idx] = Results[Edx];
						end
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Top));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]]();
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]]();
						VIP = VIP + 1;
						Inst = Instr[VIP];
						do
							return;
						end
					else
						local K;
						local B;
						local A;
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						B = Inst[3];
						K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						VIP = Inst[3];
					end
				elseif (Enum <= 188) then
					if (Enum <= 185) then
						if (Enum <= 183) then
							local K;
							local B;
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							B = Inst[3];
							K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
						elseif (Enum == 184) then
							local B;
							local A;
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A](Stk[A + 1]);
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Upvalues[Inst[3]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3];
							VIP = VIP + 1;
							Inst = Instr[VIP];
							A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							VIP = VIP + 1;
							Inst = Instr[VIP];
							Stk[Inst[2]] = Inst[3] ~= 0;
						else
							local NewProto = Proto[Inst[3]];
							local NewUvals;
							local Indexes = {};
							NewUvals = Setmetatable({}, {__index=function(_, Key)
								local Val = Indexes[Key];
								return Val[1][Val[2]];
							end,__newindex=function(_, Key, Value)
								local Val = Indexes[Key];
								Val[1][Val[2]] = Value;
							end});
							for Idx = 1, Inst[4] do
								VIP = VIP + 1;
								local Mvm = Instr[VIP];
								if (Mvm[1] == 80) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						end
					elseif (Enum <= 186) then
						local Edx;
						local Results, Limit;
						local B;
						local A;
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Results, Limit = _R(Stk[A](Unpack(Stk, A + 1, Inst[3])));
						Top = (Limit + A) - 1;
						Edx = 0;
						for Idx = A, Top do
							Edx = Edx + 1;
							Stk[Idx] = Results[Edx];
						end
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Top));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						if not Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum == 187) then
						local B;
						local A;
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = {};
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Upvalues[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						do
							return Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						do
							return Unpack(Stk, A, Top);
						end
						VIP = VIP + 1;
						Inst = Instr[VIP];
						do
							return;
						end
					elseif (Inst[2] < Stk[Inst[4]]) then
						VIP = Inst[3];
					else
						VIP = VIP + 1;
					end
				elseif (Enum <= 191) then
					if (Enum <= 189) then
						local B;
						local A;
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						if Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum == 190) then
						local B;
						local A;
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						VIP = VIP + 1;
						Inst = Instr[VIP];
						if Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Stk[Inst[2]] <= Stk[Inst[4]]) then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				elseif (Enum <= 193) then
					if (Enum > 192) then
						if (Stk[Inst[2]] ~= Stk[Inst[4]]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					else
						local K;
						local B;
						local A;
						Stk[Inst[2]] = Inst[3];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Env[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						B = Inst[3];
						K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
						VIP = VIP + 1;
						Inst = Instr[VIP];
						A = Inst[2];
						Stk[A](Stk[A + 1]);
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Inst[3] ~= 0;
						VIP = VIP + 1;
						Inst = Instr[VIP];
						Stk[Inst[2]] = Stk[Inst[3]];
						VIP = VIP + 1;
						Inst = Instr[VIP];
						VIP = Inst[3];
					end
				elseif (Enum == 194) then
					Stk[Inst[2]] = #Stk[Inst[3]];
				else
					local A;
					Stk[Inst[2]] = Inst[3];
					VIP = VIP + 1;
					Inst = Instr[VIP];
					A = Inst[2];
					Stk[A](Stk[A + 1]);
					VIP = VIP + 1;
					Inst = Instr[VIP];
					Stk[Inst[2]] = Upvalues[Inst[3]];
					VIP = VIP + 1;
					Inst = Instr[VIP];
					Stk[Inst[2]]();
					VIP = VIP + 1;
					Inst = Instr[VIP];
					do
						return;
					end
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!753Q0003073Q0067657467656E76030E3Q005069636B487562422Q6F7374657203093Q004175746F53747261742Q0103083Q004175746F536B6970010003073Q00416E74694C6167030B3Q004175746F5069636B757073030B3Q0053656E64576562682Q6F6B03073Q00576562682Q6F6B034Q0003073Q004C6F61646F757403043Q004D6F646503083Q0047616D65496E666F03093Q0054696D655363616C6503083Q006D6163726F55524C03073Q00414E544941464B0003083Q006175746F736B697003043Q007461736B03043Q007761697403043Q0067616D6503083Q0049734C6F61646564030A3Q004765745365727669636503073Q00506C6179657273030B3Q004C6F63616C506C61796572030C3Q0057616974466F724368696C6403093Q00506C61796572477569026Q002440030A3Q006C6F6164737472696E6703073Q00482Q747047657403213Q00682Q7470733A2Q2F706173746562696E2E636F6D2F7261772F694A53327247667603063Q00736861726564030C3Q004175746F537472617447554903073Q00436F6E736F6C65026Q00594003073Q0072657175657374030C3Q00682Q74705F72657175657374030B3Q00682Q74707265717565737403093Q0047657444657669636503043Q007761726E03193Q006661696C7572653A206E6F20682Q74702066756E6374696F6E03113Q005265706C69636174656453746F72616765030E3Q0052656D6F746546756E6374696F6E030B3Q0052656D6F74654576656E74030B3Q00506C61796572412Q64656403043Q0057616974030B3Q0031372Q343735303739313003133Q0054696D657363616C65205469636B6574287329030B3Q00313734333834382Q363930030D3Q0052616E676520466C6167287329030B3Q003137343338343836313338030E3Q0044616D61676520466C6167287329030B3Q00313734333834383Q373403103Q00432Q6F6C646F776E20466C6167287329030B3Q003137343239353337302Q32030B3Q00426C692Q7A617264287329030B3Q0031372Q343835393637343903103Q004E6170616C6D20537472696B65287329030B3Q003138343933303733352Q33030E3Q005370696E205469636B6574287329030B3Q003137343239353438333035030E3Q0053752Q706C792044726F70287329030B3Q0031382Q3433322Q37333038031D3Q004C6F7720477261646520436F6E73756D61626C65204372617465287329030F3Q00313336313830333832313335303438030E3Q0053616E746120526164696F287329030B3Q0031382Q3433322Q37313036031D3Q004D696420477261646520436F6E73756D61626C65204372617465287329030B3Q0031382Q3433322Q37353931031E3Q004869676820477261646520436F6E73756D61626C65204372617465287329030F3Q00313332312Q35373937362Q3231353603113Q004368726973746D61732054722Q65287329030F3Q00313234303635383735322Q30393239030D3Q0046727569742043616B65287329030B3Q003137343239353431353133030C3Q0042612Q726963616465287329030F3Q002Q313034313530373334332Q36303403143Q00486F6C792048616E64204772656E616465287329030F3Q00313339343134392Q32332Q3538303303133Q0050726573656E7420436C757374657273287329030D3Q00706C616365645F746F77657273030C3Q006163746976655F7374726174030F3Q006D617463686D616B696E675F6D617003083Q0048617264636F726503083Q0068617264636F7265030B3Q0050692Q7A6120506172747903093Q0068612Q6C6F772Q656E03083Q004261646C616E647303083Q006261646C616E647303083Q00506F2Q6C7574656403083Q00706F2Q6C7574656403093Q005444535F5461626C65028Q0003043Q0047414D4503053Q007063612Q6C03063Q00412Q646F6E73030F3Q0054656C65706F7274546F4C6F2Q627903083Q00566F7465536B6970030F3Q00556E6C6F636B54696D655363616C6503093Q00537461727447616D6503053Q00526561647903073Q0047657457617665030B3Q005265737461727447616D6503053Q00506C61636503073Q005570677261646503093Q0053657454617267657403043Q0053652Q6C03073Q0053652Q6C412Q6C03073Q004162696C69747903093Q004175746F436861696E03093Q005365744F7074696F6E03063Q00756E7061636B03043Q007479706503063Q006E756D626572026Q00F03F03053Q00737061776E00CE012Q0012553Q00014Q009E3Q0001000200203C5Q00020006AE3Q0015000100010004523Q001500012Q004B00013Q000C00303D00010003000400302Q00010005000600302Q00010007000400302Q00010008000600302Q00010009000600302Q0001000A000B4Q00025Q00102Q0001000C000200302Q0001000D000B4Q00025Q0010A30001000E00020030680001000F000600306800010010000B0030680001001100062Q00503Q00013Q00203C00013Q000500267D0001001D000100120004523Q001D000100203C00013Q00130026050001001D000100120004523Q001D000100203C00013Q00130010A33Q0005000100203C00013Q00050006AE00010021000100010004523Q002100012Q008B00015Q0010A33Q0005000100203C00013Q00080006AE00010026000100010004523Q002600012Q008B00015Q0010A33Q0008000100203C00013Q00070006AE0001002B000100010004523Q002B00012Q008B00015Q0010A33Q0007000100203C00013Q00090006AE00010030000100010004523Q003000012Q008B00015Q0010A33Q0009000100203C00013Q000A0006AE00010035000100010004523Q003500010012770001000B3Q0010A33Q000A000100203C00013Q00100006AE0001003A000100010004523Q003A00010012770001000B3Q0010A33Q0010000100203C00013Q00110006AE0001003F000100010004523Q003F00012Q008B00015Q0010A33Q00110001001255000100143Q0020010001000100154Q00010001000100122Q000100163Q00202Q0001000100174Q00010002000200062Q0001004000013Q0004523Q00400001001255000100163Q00209300010001001800122Q000300196Q00010003000200202Q00010001001A00202Q00020001001B00122Q0004001C6Q0002000400020006B900033Q000100022Q00503Q00024Q00503Q00014Q0050000400034Q009E0004000100020006AE0004005F000100010004523Q005F0001001255000400143Q00200F00040004001500122Q0005001D6Q0004000200014Q000400036Q00040001000200062Q0004005700013Q0004523Q005700010012550004001E3Q00123A000500163Q00202Q00050005001F00122Q000700206Q000500076Q00043Q00024Q00040001000100122Q000400213Q00202Q00040004002200202Q0004000400234Q00055Q001277000600243Q000267000700013Q0006B900080002000100032Q00503Q00074Q00503Q00054Q00503Q00063Q000267000900034Q0050000A00094Q009E000A00010002001255000B00253Q0006AE000B0082000100010004523Q00820001001255000B00263Q0006AE000B0082000100010004523Q00820001001255000B00273Q0006AE000B0082000100010004523Q00820001001255000B00283Q00066A000B008200013Q0004523Q00820001001255000B00284Q009E000B0001000200203C000B000B00250006AE000B0088000100010004523Q00880001001255000C00293Q001277000D002A4Q005D000C000200012Q00293Q00013Q001255000C00163Q00203F000C000C001800122Q000E002B6Q000C000E000200202Q000D000C001B00122Q000F002C6Q000D000F000200202Q000E000C001B00122Q0010002D6Q000E001000020012A5000F00163Q00202Q000F000F001800122Q001100196Q000F0011000200202Q0010000F001A00062Q0010009C000100010004523Q009C000100203C0010000F002E00200E00100010002F2Q004900100002000200200E00110010001B0012AF0013001C6Q0011001300024Q00128Q00138Q00148Q00158Q00163Q001100304A00160030003100302Q00160032003300302Q00160034003500302Q00160036003700302Q00160038003900302Q0016003A003B00302Q0016003C003D00302Q0016003E003F00302Q00160040004100302Q00160042004300302Q00160044004500302Q00160046004700302Q0016004800490030330016004A004B00302Q0016004C004D00302Q0016004E004F00302Q0016005000514Q00173Q00034Q00185Q00102Q00170052001800302Q0017005300044Q00183Q000400302Q00180055005600306800180057005800301200180059005A00302Q0018005B005C00102Q0017005400184Q00185Q00122Q001900213Q00102Q0019005D001700122Q0019005E3Q00122Q001A005E3Q00122Q001B005E3Q00122Q001C005E3Q002605000A00C90001005F0004523Q00C900010004523Q00D20001001255001D00603Q0006B9001E0004000100062Q00503Q00104Q00503Q00084Q00503Q00194Q00503Q001A4Q00503Q001B4Q00503Q001C4Q005D001D00020001000267001D00053Q0006B9001E0006000100032Q00503Q00114Q00503Q00104Q00503Q00163Q000267001F00073Q0006B900200008000100082Q00503Q00114Q00503Q001F4Q00508Q00503Q001E4Q00503Q001A4Q00503Q001C4Q00503Q00104Q00503Q000B3Q0006B900210009000100042Q00508Q00503Q00194Q00503Q001B4Q00503Q000B3Q0006B90022000A000100022Q00503Q000D4Q00503Q00083Q0006B90023000B000100032Q00503Q00084Q00503Q00224Q00503Q00213Q0006B90024000C000100022Q00503Q00084Q00503Q000E3Q0006B90025000D000100022Q00503Q00084Q00503Q000E3Q0006B90026000E000100052Q00503Q00084Q00503Q000D4Q00503Q00244Q00503Q00254Q00503Q00233Q0006B90027000F000100022Q00503Q000C4Q00503Q00083Q0006B900280010000100022Q00503Q00084Q00503Q000C3Q0006B900290011000100032Q00503Q00104Q00503Q00084Q00503Q000C3Q0006B9002A0012000100032Q00503Q00084Q00503Q00114Q00503Q00223Q0006B9002B0013000100012Q00503Q00113Q0006B9002C0014000100032Q00503Q000D4Q00503Q001D4Q00503Q00083Q0006B9002D0015000100032Q00503Q000D4Q00503Q001D4Q00503Q00083Q0006B9002E0016000100032Q00503Q000D4Q00503Q001D4Q00503Q00083Q0006B9002F0017000100042Q00503Q002B4Q00503Q000D4Q00503Q001D4Q00503Q00083Q0006B900300018000100032Q00503Q00174Q00503Q000D4Q00503Q001D3Q0006B900310019000100052Q00503Q000A4Q00503Q00114Q00503Q00174Q00503Q001D4Q00503Q00083Q0010A30017000D00310006B90031001A000100032Q00508Q00503Q000A4Q00503Q00083Q0010A30017000C00310006B90031001B000100022Q00503Q000A4Q00503Q00173Q0010A30017006100310006B90031001C000100012Q00503Q001F3Q0010A30017006200310006B90031001D000100032Q00503Q002B4Q00503Q00084Q00503Q00223Q0010A30017006300310006B90031001E000100052Q00503Q000A4Q00503Q00084Q00503Q00114Q00503Q00274Q00503Q00263Q0010A30017000E00310006B90031001F000100012Q00503Q00293Q0010A30017006400310006B900310020000100012Q00503Q00283Q0010A30017000F00310006B900310021000100022Q00503Q00084Q00503Q00253Q0010A30017006500310006B900310022000100022Q00503Q000A4Q00503Q00233Q0010A30017006600310006B900310023000100012Q00503Q002B3Q0010A30017006700310006B900310024000100012Q00503Q002A3Q0010A30017006800310006B900310025000100042Q00503Q000A4Q00503Q00104Q00503Q00084Q00503Q002C3Q0010A30017006900310006B900310026000100022Q00503Q002D4Q00503Q00183Q0010A30017006A00310006B900310027000100032Q00503Q002B4Q00503Q000D4Q00503Q00083Q0010A30017006B00310006B900310028000100032Q00503Q002B4Q00503Q002E4Q00503Q00083Q0010A30017006C00310006B900310029000100032Q00503Q002B4Q00503Q002E4Q00503Q00083Q0010A30017006D00310006B90031002A000100012Q00503Q00303Q0010A30017006E00310006B90031002B000100042Q00503Q00174Q00503Q00084Q00503Q00304Q00503Q00113Q0010A30017006F00310006B90031002C000100012Q00503Q002F3Q0010A30017007000310002670031002D3Q0006B90032002E000100012Q00503Q00103Q0006B90033002F000100052Q00503Q00134Q00508Q00503Q00324Q00503Q00314Q00503Q00083Q0006B900340030000100052Q00503Q00144Q00508Q00503Q00114Q00503Q00084Q00503Q00223Q0006B900350031000100022Q00503Q00124Q00503Q00203Q0006B900360032000100022Q00503Q00154Q00507Q000267003700333Q000267003800344Q0040003900356Q0039000100014Q003900346Q0039000100014Q003900336Q0039000100014Q003900366Q00390001000100202Q00393Q001100062Q0039009A2Q013Q0004523Q009A2Q012Q0050003900374Q00110039000100012Q0050003900384Q001100390001000100203C00393Q000C00066A003900A42Q013Q0004523Q00A42Q0100200E00390017000C001255003B00713Q00203C003C3Q000C2Q0051003B003C4Q004200393Q000100203C00393Q000D00066A003900AA2Q013Q0004523Q00AA2Q0100200E00390017000D00203C003B3Q000D2Q008F0039003B000100203C00393Q000E00066A003900B22Q013Q0004523Q00B22Q0100200E00390017000E001255003B00713Q00203C003C3Q000E2Q0051003B003C4Q004200393Q000100203C00393Q000F00066A003900C32Q013Q0004523Q00C32Q01001255003900723Q00203C003A3Q000F2Q004900390002000200267D003900C32Q0100730004523Q00C32Q0100200E0039001700642Q002A00390002000100122Q003900143Q00202Q00390039001500122Q003A00746Q00390002000100202Q00390017000F00202Q003B3Q000F4Q0039003B000100203C00393Q001000066A003900CC2Q013Q0004523Q00CC2Q01001255003900143Q00203C0039003900750006B9003A0035000100022Q00508Q00503Q00174Q005D0039000200012Q007C001700024Q00293Q00013Q00363Q00053Q00030E3Q0046696E6446697273744368696C6403073Q0047616D6547756903083Q004C6F2Q627947756903093Q0043686172616374657203103Q0048756D616E6F6964522Q6F7450617274001C4Q009F7Q00206Q000100122Q000200028Q0002000200064Q000A000100010004523Q000A00012Q00887Q00200E5Q0001001277000200034Q00153Q0002000200066A3Q001900013Q0004523Q001900012Q0088000100013Q00203C00010001000400066A0001001900013Q0004523Q001900012Q0088000100013Q0020B100010001000400202Q00010001000100122Q000300056Q00010003000200062Q0001001900013Q0004523Q001900012Q008B000100014Q007C000100024Q008B00016Q007C000100024Q00293Q00017Q00173Q0003053Q006C6F77657203043Q0066696E6403053Q00652Q726F7203063Q006661696C656403073Q00696E76616C696403073Q006D692Q73696E6703063Q0063612Q6E6F742Q033Q006E696C2Q033Q006E6F202Q033Q0072656403073Q007761726E696E6703053Q00692Q73756503053Q00726574727903073Q00736B692Q70656403053Q0064656C617903063Q006F72616E676503063Q006C6F6164656403083Q00646574656374656403073Q007570646174656403083Q0061646A7573746564030A3Q0070726F63652Q73696E6703063Q0079652Q6C6F7703053Q0067722Q656E01603Q00201F00013Q00014Q00010002000200202Q00020001000200122Q000400036Q00020004000200062Q00020025000100010004523Q0025000100200E000200010002001277000400044Q00150002000400020006AE00020025000100010004523Q0025000100200E000200010002001277000400054Q00150002000400020006AE00020025000100010004523Q0025000100200E000200010002001277000400064Q00150002000400020006AE00020025000100010004523Q0025000100200E000200010002001277000400074Q00150002000400020006AE00020025000100010004523Q0025000100200E000200010002001277000400084Q00150002000400020006AE00020025000100010004523Q0025000100200E000200010002001277000400094Q001500020004000200066A0002002700013Q0004523Q002700010012770002000A4Q007C000200023Q00200E0002000100020012770004000B4Q00150002000400020006AE00020040000100010004523Q0040000100200E0002000100020012770004000C4Q00150002000400020006AE00020040000100010004523Q0040000100200E0002000100020012770004000D4Q00150002000400020006AE00020040000100010004523Q0040000100200E0002000100020012770004000E4Q00150002000400020006AE00020040000100010004523Q0040000100200E0002000100020012770004000F4Q001500020004000200066A0002004200013Q0004523Q00420001001277000200104Q007C000200023Q00200E000200010002001277000400114Q00150002000400020006AE0002005B000100010004523Q005B000100200E000200010002001277000400124Q00150002000400020006AE0002005B000100010004523Q005B000100200E000200010002001277000400134Q00150002000400020006AE0002005B000100010004523Q005B000100200E000200010002001277000400144Q00150002000400020006AE0002005B000100010004523Q005B000100200E000200010002001277000400154Q001500020004000200066A0002005D00013Q0004523Q005D0001001277000200164Q007C000200023Q001277000200174Q007C000200024Q00293Q00017Q00443Q0003063Q00736861726564030C3Q004175746F537472617447554903073Q00436F6E736F6C6503153Q0046696E6446697273744368696C644F66436C612Q73030C3Q0055494C6973744C61796F757403063Q00747970656F6603063Q00436F6C6F723303043Q006D61746803053Q00666C2Q6F7203013Q0052025Q00E06F4003013Q004703013Q004203063Q00737472696E6703063Q00666F726D6174030D3Q00232530327825303278253032782Q033Q0072656403073Q00232Q663464346403063Q006F72616E676503073Q00232Q663966343303063Q0079652Q6C6F7703073Q002366656361353703053Q0067722Q656E03073Q00232Q302Q66393603023Q006F7303043Q006461746503083Q0025483A254D3A2553033C3Q003C666F6E7420636F6C6F723D2723646364636463273E5B25735D3C2F666F6E743E203C666F6E7420636F6C6F723D272573273E25733C2F666F6E743E03083Q00496E7374616E63652Q033Q006E657703093Q00546578744C6162656C03043Q004E616D6503083Q004C6F67456E74727903163Q004261636B67726F756E645472616E73706172656E6379026Q00F03F03043Q0053697A6503053Q005544696D32026Q0020C0028Q0003043Q00466F6E7403043Q00456E756D03123Q00536F7572636553616E7353656D69626F6C6403083Q0052696368546578742Q0103043Q005465787403083Q005465787453697A65026Q002C40030B3Q00546578745772612Q706564030E3Q005465787458416C69676E6D656E7403043Q004C656674030A3Q0054657874436F6C6F723303073Q0066726F6D52474203163Q00546578745374726F6B655472616E73706172656E637903103Q00546578745374726F6B65436F6C6F7233030D3Q004175746F6D6174696353697A6503013Q005903063Q00506172656E7403053Q007461626C6503063Q00696E7365727403073Q0044657374726F7903063Q0072656D6F766503043Q007461736B03043Q0077616974030A3Q0043616E76617353697A6503133Q004162736F6C757465436F6E74656E7453697A65030E3Q0043616E766173506F736974696F6E03073Q00566563746F723203063Q004F2Q6673657402A13Q001255000200013Q00203C00020002000200066A0002000700013Q0004523Q00070001001255000200013Q00203C00020002000200203C0002000200030006AE0002000A000100010004523Q000A00012Q00293Q00013Q00200E000300020004001204000500056Q0003000500024Q000400043Q00122Q000500066Q000600016Q00050002000200262Q0005002B000100070004523Q002B0001001255000500083Q00206000050005000900202Q00060001000A00202Q00060006000B4Q00050002000200122Q000600083Q00202Q00060006000900202Q00070001000C00202Q00070007000B4Q00060002000200122Q000700083Q00202Q00070007000900202Q00080001000D00202Q00080008000B4Q00070002000200122Q0008000E3Q00202Q00080008000F00122Q000900106Q000A00056Q000B00066Q000C00076Q0008000C00024Q000400083Q00044Q003D00010006AE00010034000100010004523Q003400012Q008800055Q00069D00010034000100050004523Q003400012Q008800056Q005000066Q00490005000200022Q0050000100054Q004B00053Q000400302D00050011001200302Q00050013001400302Q00050015001600302Q0005001700184Q00060005000100062Q0004003D000100060004523Q003D0001001277000400183Q001255000500193Q00207F00050005001A00122Q0006001B6Q00050002000200122Q0006000E3Q00202Q00060006000F00122Q0007001C6Q000800056Q000900046Q000A8Q0006000A000200122Q0007001D3Q00202Q00070007001E00122Q0008001F6Q00070002000200302Q00070020002100302Q00070022002300122Q000800253Q00202Q00080008001E00122Q000900233Q00122Q000A00263Q00122Q000B00273Q00122Q000C00276Q0008000C000200102Q00070024000800122Q000800293Q00202Q00080008002800202Q00080008002A00102Q00070028000800302Q0007002B002C00102Q0007002D000600302Q0007002E002F00302Q00070030002C00122Q000800293Q00202Q00080008003100202Q00080008003200102Q00070031000800122Q000800073Q00202Q00080008003400122Q0009000B3Q00122Q000A000B3Q00122Q000B000B6Q0008000B000200102Q00070033000800302Q00070035002700122Q000800073Q00202Q00080008003400122Q000900273Q00122Q000A00273Q00122Q000B00276Q0008000B000200102Q00070036000800122Q000800293Q00202Q00080008003700202Q00080008003800102Q00070037000800102Q00070039000200122Q0008003A3Q00202Q00080008003B4Q000900016Q000A00076Q0008000A00014Q000800016Q000800086Q000900023Q00062Q00080081000100090004523Q008100010004523Q008A00012Q0088000800013Q00208900080008002300202Q00080008003C4Q00080002000100122Q0008003A3Q00202Q00080008003D4Q000900013Q00122Q000A00236Q0008000A00010012550008003E3Q00203C00080008003F2Q001100080001000100066A000300A000013Q0004523Q00A00001001255000800253Q0020B000080008001E00122Q000900273Q00122Q000A00273Q00122Q000B00273Q00202Q000C0003004100202Q000C000C00384Q0008000C000200102Q00020040000800122Q000800433Q00202Q00080008001E00122Q000900273Q00202Q000A0002004000202Q000A000A003800202Q000A000A00444Q0008000A000200102Q0002004200082Q00293Q00017Q00103Q0003043Q0067616D65030A3Q004765745365727669636503073Q00506C6179657273030B3Q004C6F63616C506C61796572030B3Q00506C61796572412Q64656403043Q0057616974030C3Q0057616974466F724368696C6403093Q00506C61796572477569030E3Q0046696E6446697273744368696C6403083Q004C6F2Q627947756903053Q004C4F2Q425903073Q0047616D6547756903043Q0047414D4503043Q007461736B03043Q0077616974026Q00F03F00223Q0012A53Q00013Q00206Q000200122Q000200038Q0002000200202Q00013Q000400062Q0001000A000100010004523Q000A000100203C00013Q000500200E0001000100062Q004900010002000200200E000200010007001277000400084Q001500020004000200200E0003000200090012770005000A4Q001500030005000200066A0003001500013Q0004523Q001500010012770003000B4Q007C000300023Q0004523Q001C000100200E0003000200090012770005000C4Q001500030005000200066A0003001C00013Q0004523Q001C00010012770003000D4Q007C000300023Q0012550003000E3Q00203C00030003000F001277000400104Q005D0003000200010004523Q000D00012Q00293Q00017Q00093Q0003043Q007461736B03043Q0077616974026Q00F03F030E3Q0046696E6446697273744368696C6403053Q00436F696E7303103Q0043752Q72656E7420436F696E733A202403083Q00746F737472696E6703053Q0056616C756503043Q0047656D7300203Q0012553Q00013Q0020AB5Q000200122Q000100038Q000200019Q0000206Q000400122Q000200058Q0002000200066Q00013Q0004525Q00012Q00883Q00013Q001245000100063Q00122Q000200076Q00035Q00202Q00030003000500202Q0003000300084Q0002000200024Q0001000100026Q000200019Q0000206Q000500206Q00086Q00028Q00028Q00039Q003Q00206Q000900206Q00086Q00048Q00048Q00058Q00017Q00063Q002Q0103043Q007479706503053Q007461626C6503073Q0053752Q63652Q7303053Q007063612Q6C03083Q00757365726461746101243Q0026053Q0003000100010004523Q000300010004523Q000500012Q008B000100014Q007C000100023Q001255000100024Q005000026Q004900010002000200267D0001000F000100030004523Q000F000100203C00013Q000400267D0001000F000100010004523Q000F00012Q008B000100014Q007C000100023Q001255000100053Q0006B900023Q000100012Q00508Q008E00010002000200066A0001001900013Q0004523Q0019000100066A0002001900013Q0004523Q001900012Q008B000300014Q007C000300023Q001255000300024Q005000046Q00490003000200020026050003001F000100060004523Q001F00010004523Q002100012Q008B000300014Q007C000300024Q008B00036Q007C000300024Q00293Q00013Q00013Q00023Q002Q033Q0049734103053Q004D6F64656C00094Q00887Q00066A3Q000700013Q0004523Q000700012Q00887Q00200E5Q0001001277000200024Q00153Q000200022Q007C3Q00024Q00293Q00017Q003A3Q0003053Q00436F696E73028Q0003043Q0047656D7303023Q00585003043Q005761766503053Q004C6576656C03043Q0054696D6503053Q002Q303A2Q3003063Q0053746174757303073Q00554E4B4E4F574E03063Q004F7468657273030E3Q0046696E6446697273744368696C6403133Q00526561637447616D654E65775265776172647303053Q004672616D6503083Q0067616D654F766572030D3Q00526577617264735363722Q656E03093Q0067616D65537461747303053Q00737461747303063Q00697061697273030B3Q004765744368696C6472656E03093Q00746578744C6162656C030A3Q00746578744C6162656C3203043Q005465787403043Q0066696E64030F3Q0054696D6520436F6D706C657465643A030C3Q0052657761726442612Q6E657203053Q00752Q70657203073Q00545249554D50482Q033Q0057494E03043Q004C4F535403043Q004C4F2Q5303053Q0056616C7565030C3Q0057616974466F724368696C6403173Q00526561637447616D65546F7047616D65446973706C617903043Q007761766503093Q00636F6E7461696E657203053Q0076616C756503053Q006D6174636803063Q005E2825642B2903083Q00746F6E756D626572030E3Q005265776172647353656374696F6E03043Q004E616D6503013Q003003163Q0046696E6446697273744368696C645768696368497341030A3Q00496D6167654C6162656C03053Q00496D6167652Q033Q0025642B030E3Q0047657444657363656E64616E74732Q033Q0049734103093Q00546578744C6162656C03053Q002825642B2903053Q006C6F77657203043Q007825642B030E3Q00556E6B6E6F776E204974656D202803013Q002903053Q007461626C6503063Q00696E7365727403063Q00416D6F756E7400E94Q00065Q000800304Q0001000200304Q0003000200304Q0004000200304Q0005000200304Q0006000200304Q0007000800304Q0009000A4Q00015Q00104Q000B00014Q00015Q00202Q00010001000C00122Q0003000D6Q00010003000200062Q00020013000100010004523Q0013000100200E00020001000C0012770004000E4Q001500020004000200069D00030018000100020004523Q0018000100200E00030002000C0012770005000F4Q001500030005000200069D0004001D000100030004523Q001D000100200E00040003000C001277000600104Q001500040006000200069D00050022000100040004523Q0022000100200E00050004000C001277000700114Q001500050007000200069D00060027000100050004523Q0027000100200E00060005000C001277000800124Q001500060008000200066A0006004300013Q0004523Q00430001001255000700133Q00200E0008000600142Q0051000800094Q00AD00073Q00090004523Q0041000100200E000C000B000C001222000E00156Q000C000E000200202Q000D000B000C00122Q000F00166Q000D000F000200062Q000C004100013Q0004523Q0041000100066A000D004100013Q0004523Q0041000100203C000E000C001700200E000E000E0018001277001000194Q0015000E0010000200066A000E004100013Q0004523Q0041000100203C000E000D00170010A33Q0007000E0004523Q0043000100067E0007002E000100020004523Q002E000100069D00070048000100040004523Q0048000100200E00070004000C0012770009001A4Q001500070009000200066A0007006500013Q0004523Q0065000100200E00080007000C001277000A00154Q00150008000A000200066A0008006500013Q0004523Q0065000100203C00080007001500206900080008001700202Q00080008001B4Q00080002000200202Q00090008001800122Q000B001C6Q0009000B000200062Q0009005B00013Q0004523Q005B00010012770009001D3Q0006AE00090064000100010004523Q0064000100200E000900080018001277000B001E4Q00150009000B000200066A0009006300013Q0004523Q006300010012770009001F3Q0006AE00090064000100010004523Q006400010012770009000A3Q0010A33Q000900092Q0088000800013Q00203C00080008000600066A0008006E00013Q0004523Q006E000100203C0009000800200006AE0009006D000100010004523Q006D0001001277000900023Q0010A33Q000600092Q008800095Q00203600090009002100122Q000B00226Q0009000B000200202Q00090009000E00202Q00090009002300202Q00090009002400202Q00090009002500202Q000A0009001700202Q000A000A002600122Q000C00276Q000A000C000200062Q000A008300013Q0004523Q00830001001255000B00284Q0050000C000A4Q0049000B000200020006AE000B0082000100010004523Q00820001001277000B00023Q0010A33Q0005000B00069D000B0088000100040004523Q0088000100200E000B0004000C001277000D00294Q0015000B000D000200066A000B00E700013Q0004523Q00E70001001255000C00133Q00200E000D000B00142Q0051000D000E4Q00AD000C3Q000E0004523Q00E50001001255001100283Q00203C00120010002A2Q004900110002000200066A001100E500013Q0004523Q00E500010012770011002B3Q00206200120010002C00122Q0014002D6Q001500016Q00120015000200062Q001200A200013Q0004523Q00A2000100203C00130012002E00200E0013001300260012770015002F4Q0015001300150002000617001100A2000100130004523Q00A200010012770011002B3Q001255001300133Q00200E0014001000302Q0051001400154Q00AD00133Q00150004523Q00E3000100200E001800170031001277001A00324Q00150018001A000200066A001800E300013Q0004523Q00E3000100203C0018001700170012BA001900283Q00202Q001A0018002600122Q001C00336Q001A001C6Q00193Q000200062Q001900B5000100010004523Q00B50001001277001900023Q00200E001A00180018001277001C00014Q0015001A001C000200066A001A00BC00013Q0004523Q00BC00010010A33Q000100190004523Q00E3000100200E001A00180018001277001C00034Q0015001A001C000200066A001A00C300013Q0004523Q00C300010010A33Q000300190004523Q00E3000100200E001A00180018001277001C00044Q0015001A001C000200066A001A00CA00013Q0004523Q00CA00010010A33Q000400190004523Q00E3000100200E001A001800342Q00B2001A0002000200202Q001A001A001800122Q001C00356Q001A001C000200062Q001A00E300013Q0004523Q00E300012Q0088001A00024Q0096001A001A00110006AE001A00D9000100010004523Q00D90001001277001A00364Q0050001B00113Q001277001C00374Q008A001A001A001C001255001B00383Q002053001B001B003900202Q001C3Q000B4Q001D3Q000200202Q001E0018002600122Q002000356Q001E0020000200102Q001D003A001E00102Q001D002A001A4Q001B001D000100067E001300A7000100020004523Q00A7000100067E000C008F000100020004523Q008F00012Q007C3Q00024Q00293Q00017Q00093Q0003043Q007461736B03043Q0077616974026Q00F03F03043Q0067616D6503113Q005265706C69636174656453746F7261676503073Q004E6574776F726B03083Q0054656C65706F7274030E3Q0052453A6261636B546F4C6F2Q6279030A3Q0046697265536572766572000C3Q0012A03Q00013Q00206Q000200122Q000100038Q0002000100124Q00043Q00206Q000500206Q000600206Q000700206Q000800202Q00013Q00094Q0001000200016Q00017Q004B3Q0003043Q007461736B03043Q0077616974026Q00F03F030E3Q0046696E6446697273744368696C6403133Q00526561637447616D654E65775265776172647303053Q004672616D6503083Q0067616D654F766572030D3Q00526577617264735363722Q656E030E3Q005265776172647353656374696F6E030B3Q0053656E64576562682Q6F6B03053Q00436F696E7303043Q0047656D73034Q0003063Q004F7468657273028Q0003063Q0069706169727303073Q00F09F8E81202Q2A03063Q00416D6F756E7403013Q002003043Q004E616D652Q033Q002Q2A0A03193Q005F4E6F20626F6E7573207265776172647320666F756E642E5F03083Q00757365726E616D65031B3Q005069636B487562205B204175746F2D5374726174205D20F09F92A103063Q00656D6265647303053Q007469746C6503063Q005374617475732Q033Q0057494E03163Q00F09F8F8620566963746F727920556E6C6F636B65642103183Q00F09F9280204F6F663Q2E204120546F756768204C6F2Q7303053Q00636F6C6F72023Q00C0366B6341030B3Q006465736372697074696F6E03193Q003Q2320F09F9391204D6174636820427265616B646F776E0A030F3Q003E202Q2A5374617475733A2Q2A206003023Q00600A03143Q003E202Q2A54696D6520506C617965643A2Q2A206003043Q0054696D6503193Q003E202Q2A4C6576656C2050726F6772652Q7365643A2Q2A206003053Q004C6576656C03163Q003E202Q2A576176652041636869657665643A2Q2A206003043Q005761766503063Q006669656C647303043Q006E616D6503153Q00F09F928E205265776172647320556E6C6F636B656403053Q0076616C756503083Q003Q60616E73690A03183Q001B5B323B2Q336DF09F92B020436F696E733A1B5B306D202B03013Q000A03183Q001B5B323B33346DF09F928E2047656D733A201B5B306D202B03193Q001B5B323B33326DF09F93882058503A4Q201B5B306D202B03023Q0058502Q033Q003Q6003063Q00696E6C696E65010003193Q00F09F8E8120426F6E7573204974656D732047617468657265642Q0103183Q00F09F938A20546F74616C2053652Q73696F6E205374617473031F3Q003Q6070790A2320546F74616C20436F2Q6C65637465640A436F696E733A2003083Q000A47656D733A2Q2003063Q00662Q6F74657203043Q0074657874030A3Q004C6F2Q6765642062792003213Q0020E280A2204175746F2D537472617420456E67696E6520284153452920F09F8C9003093Q0074696D657374616D7003083Q004461746554696D652Q033Q006E6F7703093Q00546F49736F4461746503093Q007468756D626E61696C2Q033Q0075726C03B93Q00682Q7470733A2Q2F63646E2E646973636F7264612Q702E636F6D2F612Q746163686D656E74732F3134353138333637362Q34393831362Q3935382F31342Q353834322Q34313038343031343730332F7374616E64617264322E6769663F65783D36393562373836652669733D3639356132362Q6526686D3D65663234626530323162646361333934376663323437623365353633393061652Q313034633733626636386538653633616663303738363133313334316431302603053Q00696D61676503B93Q00682Q7470733A2Q2F63646E2E646973636F7264612Q702E636F6D2F612Q746163686D656E74732F3134353138333637362Q34393831362Q3935382F31342Q3538343Q323137383438332Q3039372F7374616E64617264312E6769663F65783D36393562373833392669733D363935613236623926686D3D6635646336612Q3937336562303365303132366132666133313836393161373461663933633237383061383Q663135622Q32362Q62613835373934653932382603053Q007063612Q6C026Q00F83F00A83Q001255000100013Q00206E00010001000200122Q000200036Q0001000200014Q00015Q00202Q00010001000400122Q000300056Q00010003000200062Q0002000D000100010004523Q000D000100200E000200010004001277000400064Q001500020004000200069D00030012000100020004523Q0012000100200E000300020004001277000500074Q001500030005000200069D00040017000100030004523Q0017000100200E000400030004001277000600084Q001500040006000200069D3Q001D000100040004523Q001D000100200E000500040004001277000700094Q00150005000700022Q00503Q00053Q00066A5Q00013Q0004525Q00010006AE3Q0024000100010004523Q002400012Q0088000100014Q0008000100014Q002400016Q0088000100023Q00203C00010001000A0006AE0001002B000100010004523Q002B00012Q0088000100014Q00110001000100012Q00293Q00014Q0088000100034Q000B0001000100024Q000200043Q00202Q00030001000B4Q0002000200034Q000200046Q000200053Q00202Q00030001000C4Q0002000200034Q000200053Q00122Q0002000D3Q00202Q00030001000E4Q000300033Q000E2Q000F0048000100030004523Q00480001001255000300103Q00203C00040001000E2Q008E0003000200050004523Q004500012Q0050000800023Q0012B7000900113Q00202Q000A0007001200122Q000B00133Q00202Q000C0007001400122Q000D00156Q00020008000D00067E0003003E000100020004523Q003E00010004523Q00490001001277000200164Q004B00033Q00020030410003001700184Q000400016Q00053Q000800202Q00060001001B00262Q000600530001001C0004523Q005300010012770006001D3Q0006AE00060054000100010004523Q005400010012770006001E3Q0010A30005001A000600302C0005001F002000122Q000600223Q00122Q000700233Q00202Q00080001001B00122Q000900243Q00122Q000A00253Q00202Q000B0001002600122Q000C00243Q00122Q000D00273Q00202Q000E0001002800122Q000F00243Q00122Q001000293Q00202Q00110001002A00122Q001200246Q00060006001200102Q0005002100064Q000600036Q00073Q000300302Q0007002C002D00122Q0008002F3Q00122Q000900303Q00202Q000A0001000B00122Q000B00313Q00122Q000C00323Q00202Q000D0001000C00122Q000E00313Q00122Q000F00333Q00202Q00100001003400122Q001100356Q00080008001100102Q0007002E000800302Q0007003600374Q00083Q000300302Q0008002C003800102Q0008002E000200302Q0008003600394Q00093Q000300302Q0009002C003A00122Q000A003B6Q000B00043Q00122Q000C003C6Q000D00053Q00122Q000E00356Q000A000A000E00102Q0009002E000A00302Q0009003600394Q0006000300010010A30005002B00062Q007600063Q000100122Q0007003F6Q000800063Q00202Q00080008001400122Q000900406Q00070007000900102Q0006003E000700102Q0005003D000600122Q000600423Q00202Q0006000600434Q00060001000200202Q0006000600444Q00060002000200102Q0005004100064Q00063Q000100302Q00060046004700102Q0005004500064Q00063Q000100302Q00060046004900102Q0005004800064Q0004000100010010A30003001900040012550004004A3Q0006B900053Q000100032Q00883Q00074Q00883Q00024Q00503Q00034Q00A200040002000100122Q000400013Q00202Q00040004000200122Q0005004B6Q0004000200014Q000400016Q0004000100016Q00013Q00013Q000C3Q002Q033Q0055726C03073Q00576562682Q6F6B03063Q004D6574686F6403043Q00504F535403073Q0048656164657273030C3Q00436F6E74656E742D5479706503103Q00612Q706C69636174696F6E2F6A736F6E03043Q00426F647903043Q0067616D65030A3Q0047657453657276696365030B3Q00482Q747053657276696365030A3Q004A534F4E456E636F646500134Q00759Q0000013Q00044Q000200013Q00202Q00020002000200102Q00010001000200302Q0001000300044Q00023Q000100302Q00020006000700102Q00010005000200122Q000200093Q00202Q00020002000A00122Q0004000B6Q00020004000200202Q00020002000C4Q000400026Q00020004000200102Q0001000800026Q000200016Q00017Q002B3Q00030B3Q0053656E64576562682Q6F6B03043Q007479706503073Q00576562682Q6F6B03063Q00737472696E67034Q0003043Q0066696E64030D3Q00594F5552252D574542482Q4F4B03083Q00757365726E616D65031B3Q005069636B487562205B204175746F2D5374726174205D20F09F92A103063Q00656D6265647303053Q007469746C6503233Q00F09F9A80202Q2A4D6174636820537461727465642053752Q63652Q7366752Q6C792Q2A030B3Q006465736372697074696F6E03593Q00546865204175746F5374726174206861732073752Q63652Q7366752Q6C79206C6F6164656420696E746F2061206E65772067616D652073652Q73696F6E20616E6420697320626567692Q6E696E6720657865637574696F6E2E03053Q00636F6C6F72023Q00C0366B634103063Q006669656C647303043Q006E616D6503133Q00F09FAA99205374617274696E6720436F696E7303053Q0076616C75652Q033Q003Q6003083Q00746F737472696E6703093Q0020436F696E733Q6003063Q00696E6C696E652Q0103123Q00F09F928E205374617274696E672047656D7303083Q002047656D733Q6003063Q0053746174757303133Q00F02Q9FA22052752Q6E696E6720536372697074010003063Q00662Q6F74657203043Q0074657874031C3Q004175746F2D537472617420456E67696E6520284153452920F09F8C9003093Q0074696D657374616D7003083Q004461746554696D652Q033Q006E6F7703093Q00546F49736F4461746503093Q007468756D626E61696C2Q033Q0075726C03B93Q00682Q7470733A2Q2F63646E2E646973636F7264612Q702E636F6D2F612Q746163686D656E74732F3134353138333637362Q34393831362Q3935382F31342Q3538373934302Q37392Q3239363035322F7374616E64617264332E6769663F65783D36393562396164622669733D363935613439356226686D3D6163393061386465392Q38352Q3437643936313662376437323336343638643438326563356662303430313665376333303762382Q356534653265662Q3162342603053Q00696D61676503B93Q00682Q7470733A2Q2F63646E2E646973636F7264612Q702E636F6D2F612Q746163686D656E74732F3134353138333637362Q34393831362Q3935382F31342Q3538343Q323137383438332Q3039372F7374616E64617264312E6769663F65783D36393562373833392669733D363935613236623926686D3D6635646336612Q3937336562303365303132366132666133313836393161373461663933633237383061383Q663135622Q32362Q62613835373934653932382603053Q007063612Q6C00524Q00887Q00203C5Q00010006AE3Q0005000100010004523Q000500012Q00293Q00013Q0012553Q00024Q008800015Q00203C0001000100032Q00493Q0002000200267D3Q000F000100040004523Q000F00012Q00887Q00203C5Q000300267D3Q0010000100050004523Q001000012Q00293Q00014Q00887Q0020B15Q000300206Q000600122Q000200078Q0002000200064Q001800013Q0004523Q001800012Q00293Q00014Q004B5Q00020030103Q000800094Q000100016Q00023Q000800302Q0002000B000C00302Q0002000D000E00302Q0002000F00104Q000300036Q00043Q000300302Q00040012001300122Q000500153Q00122Q000600166Q000700016Q00060002000200122Q000700176Q00050005000700102Q00040014000500302Q0004001800194Q00053Q000300302Q00050012001A00122Q000600153Q00122Q000700166Q000800026Q00070002000200122Q0008001B6Q00060006000800102Q00050014000600302Q0005001800194Q00063Q000300302Q00060012001C00302Q00060014001D00302Q00060018001E4Q0003000300010010A30002001100032Q006600033Q000100302Q00030020002100102Q0002001F000300122Q000300233Q00202Q0003000300244Q00030001000200202Q0003000300254Q00030002000200102Q0002002200034Q00033Q000100302Q00030027002800102Q0002002600034Q00033Q000100302Q00030027002A00102Q0002002900034Q0001000100010010A33Q000A00010012550001002B3Q0006B900023Q000100032Q00883Q00034Q00888Q00508Q005D0001000200012Q00293Q00013Q00013Q000C3Q002Q033Q0055726C03073Q00576562682Q6F6B03063Q004D6574686F6403043Q00504F535403073Q0048656164657273030C3Q00436F6E74656E742D5479706503103Q00612Q706C69636174696F6E2F6A736F6E03043Q00426F647903043Q0067616D65030A3Q0047657453657276696365030B3Q00482Q747053657276696365030A3Q004A534F4E456E636F646500134Q00759Q0000013Q00044Q000200013Q00202Q00020002000200102Q00010001000200302Q0001000300044Q00023Q000100302Q00020006000700102Q00010005000200122Q000200093Q00202Q00020002000A00122Q0004000B6Q00020004000200202Q00020002000C4Q000400026Q00020004000200102Q0001000800026Q000200016Q00017Q00053Q0003053Q007063612Q6C03093Q00566F746520536B697003043Q007461736B03043Q0077616974029A5Q99C93F00103Q0012553Q00013Q0006B900013Q000100012Q00888Q00493Q0002000200066A3Q000A00013Q0004523Q000A00012Q0088000100013Q001277000200024Q005D0001000200010004523Q000F0001001255000100033Q00203C000100010004001277000200054Q005D0001000200010004525Q00012Q00293Q00013Q00013Q00033Q00030C3Q00496E766F6B6553657276657203063Q00566F74696E6703043Q00536B697000064Q004C7Q00206Q000100122Q000200023Q00122Q000300038Q000300016Q00017Q00153Q0003043Q0067616D65030A3Q004765745365727669636503073Q00506C6179657273030B3Q004C6F63616C506C61796572030C3Q0057616974466F724368696C6403093Q00506C6179657247756903123Q0052656163744F76652Q7269646573566F7465026Q003E4003053Q004672616D65031F3Q0057616974696E6720666F72206D6174636820726561647920766F74653Q2E030E3Q0046696E6446697273744368696C6403053Q00766F74657303093Q00636F6E7461696E657203053Q00726561647903043Q007461736B03043Q0077616974026Q00E03F029A5Q99B93F03073Q0056697369626C652Q0103213Q004D617463682072656164792064657465637465642C20736B692Q70696E673Q2E00413Q0012213Q00013Q00206Q000200122Q000200038Q0002000200206Q000400206Q000500122Q000200068Q0002000200202Q00013Q000500122Q000300073Q00122Q000400086Q00010004000200062Q00020012000100010004523Q0012000100200E000200010005001277000400093Q001277000500084Q00150002000500020006AE00020015000100010004523Q001500012Q00293Q00014Q0056000300034Q008800045Q0012770005000A4Q005D0004000200010006AE00030032000100010004523Q0032000100200E00040002000B0012770006000C4Q001500040006000200066A0004002B00013Q0004523Q002B000100200E00050004000B0012770007000D4Q001500050007000200066A0005002B00013Q0004523Q002B000100200E00060005000B0012770008000E4Q001500060008000200066A0006002B00013Q0004523Q002B00012Q0050000300063Q0006AE00030019000100010004523Q001900010012550005000F3Q00203C000500050010001277000600114Q005D0005000200010004523Q001900010012550004000F3Q00206300040004001000122Q000500126Q00040002000100202Q00040003001300262Q00040032000100140004523Q003200012Q008800045Q00127A000500156Q0004000200014Q000400016Q0004000100014Q000400026Q0004000100016Q00017Q00093Q00030A3Q0053696D706C696369747903073Q00566563746F72332Q033Q006E6577028Q0003103Q00566F74696E6720666F72206D61703A2003083Q00746F737472696E67030A3Q0046697265536572766572030B3Q004C6F2Q6279566F74696E6703043Q00566F7465021A3Q0006170002000300013Q0004523Q00030001001277000200013Q0006170003000B000100010004523Q000B0001001255000300023Q00209000030003000300122Q000400043Q00122Q000500043Q00122Q000600046Q0003000600022Q008800045Q00129B000500053Q00122Q000600066Q000700026Q0006000200024Q0005000500064Q0004000200014Q000400013Q00202Q00040004000700122Q000600083Q00122Q000700096Q000800026Q000900036Q0004000900016Q00017Q00013Q0003053Q007063612Q6C00063Q0012553Q00013Q0006B900013Q000100022Q00888Q00883Q00014Q005D3Q000200012Q00293Q00013Q00013Q00043Q00031A3Q0053656E64696E67204C6F2Q6279205265616479207369676E616C030A3Q0046697265536572766572030B3Q004C6F2Q6279566F74696E6703053Q00526561647900094Q007B7Q00122Q000100018Q000200016Q00013Q00206Q000200122Q000200033Q00122Q000300048Q000300016Q00017Q000E3Q00031A3Q004F76652Q726964696E67206D61702073656C656374696F6E3A2003083Q00746F737472696E67030C3Q00496E766F6B65536572766572030B3Q004C6F2Q6279566F74696E6703083Q004F76652Q7269646503043Q007461736B03043Q0077616974026Q00084003073Q00566563746F72332Q033Q006E657702AE47E17A142E29400248E17A14AE47254002E17A14AE47014A40026Q00F03F01234Q00B600015Q00122Q000200013Q00122Q000300026Q00048Q0003000200024Q0002000200034Q0001000200014Q000100013Q00202Q00010001000300122Q000300043Q00122Q000400056Q00058Q00010005000100122Q000100063Q00202Q00010001000700122Q000200086Q0001000200014Q000100026Q00025Q00122Q000300093Q00202Q00030003000A00122Q0004000B3Q00122Q0005000C3Q00122Q0006000D6Q000300066Q00013Q000100122Q000100063Q00202Q00010001000700122Q0002000E6Q0001000200014Q000100036Q0001000100014Q000100046Q0001000100016Q00017Q00133Q00030C3Q0057616974466F724368696C6403073Q004E6574776F726B03093Q004D6F6469666965727303143Q0052463A42756C6B566F74654D6F64696669657273030D3Q0048692Q64656E456E656D6965732Q0103053Q00476C612Q7303103Q004578706C6F64696E67456E656D696573030A3Q004C696D69746174696F6E03093Q00436F2Q6D692Q746564030E3Q004865616C746879456E656D696573030D3Q0053702Q656479456E656D696573030A3Q0051756172616E74696E652Q033Q00466F67030D3Q00466C79696E67456E656D69657303053Q0042726F6B6503063Q004A61696C656403093Q00496E666C6174696F6E03053Q007063612Q6C01214Q008500015Q00202Q00010001000100122Q000300026Q00010003000200202Q00010001000100122Q000300036Q00010003000200202Q00010001000100122Q000300046Q00010003000200062Q0002001A00013Q0004523Q001A00012Q004B00023Q000D00304A00020005000600302Q00020007000600302Q00020008000600302Q00020009000600302Q0002000A000600302Q0002000B000600302Q0002000C000600302Q0002000D000600302Q0002000E000600302Q0002000F000600302Q00020010000600302Q00020011000600302Q000200120006001255000300133Q0006B900043Q000100032Q00883Q00014Q00503Q00024Q00503Q00014Q005D0003000200012Q00293Q00013Q00013Q00033Q0003123Q005069636B696E67204D6F646966696572732003083Q00746F737472696E67030C3Q00496E766F6B65536572766572000C4Q00707Q00122Q000100013Q00122Q000200026Q000300016Q0002000200024Q0001000100026Q000200016Q00023Q00206Q00034Q000200018Q000200016Q00017Q001B3Q00028Q00026Q00E03F026Q00F03F026Q00F83F027Q004003063Q0069706169727303043Q0067616D6503073Q00506C6179657273030B3Q004C6F63616C506C6179657203093Q00506C6179657247756903143Q005265616374556E6976657273616C486F7462617203053Q004672616D6503093Q0074696D657363616C6503053Q0053702Q656403083Q00746F6E756D62657203043Q005465787403053Q006D61746368030A3Q0078285B2564252E5D2B2903183Q0041646A757374696E672054696D657363616C6520746F207803083Q00746F737472696E67030E3Q0052656D6F746546756E6374696F6E030C3Q00496E766F6B65536572766572030E3Q005469636B6574734D616E61676572030E3Q004379636C6554696D655363616C6503043Q007461736B03043Q0077616974031A3Q0054696D657363616C65207365742073752Q63652Q7366752Q6C7901594Q004F000100053Q00122Q000200013Q00122Q000300023Q00122Q000400033Q00122Q000500043Q00122Q000600056Q0001000500012Q0056000200023Q001255000300064Q0050000400014Q008E0003000200050004523Q001100010006C10007000F00013Q0004523Q000F00010004523Q001100012Q0050000200063Q0004523Q0013000100067E0003000C000100020004523Q000C00010006AE00020016000100010004523Q001600012Q00293Q00013Q001255000300073Q00207900030003000800202Q00030003000900202Q00030003000A00202Q00030003000B00202Q00030003000C00202Q00030003000D00202Q00030003000E00122Q0004000F3Q00202Q00050003001000202Q00050005001100122Q000700126Q000500076Q00043Q000200062Q00040027000100010004523Q002700012Q00293Q00014Q0056000500053Q001255000600064Q0050000700014Q008E0006000200080004523Q003100010006C1000A002F000100040004523Q002F00010004523Q003100012Q0050000500093Q0004523Q0033000100067E0006002C000100020004523Q002C00010006AE00050036000100010004523Q003600012Q00293Q00014Q0043000600020005000EA60001003A000100060004523Q003A00010004523Q003C00012Q00C2000700014Q00580006000700060026780006003F000100010004523Q003F00010004523Q005800012Q008800075Q001226000800133Q00122Q000900146Q000A8Q0009000200024Q0008000800094Q00070002000100122Q000700036Q000800063Q00122Q000900033Q00042Q0007005500012Q0088000B00013Q002091000B000B001500202Q000B000B001600122Q000D00173Q00122Q000E00186Q000B000E000100122Q000B00193Q00202Q000B000B001A00122Q000C00026Q000B000200010004090007004A00012Q008800075Q0012770008001B4Q005D0007000200012Q00293Q00017Q00143Q0003103Q0054696D657363616C655469636B65747303053Q0056616C7565026Q00F03F03043Q0067616D6503073Q00506C6179657273030B3Q004C6F63616C506C6179657203093Q00506C6179657247756903143Q005265616374556E6976657273616C486F7462617203053Q004672616D6503093Q0074696D657363616C6503043Q004C6F636B03073Q0056697369626C65031F3Q00556E6C6F636B696E672054696D657363616C652077697468207469636B6574030E3Q0052656D6F746546756E6374696F6E030C3Q00496E766F6B65536572766572030E3Q005469636B6574734D616E61676572030F3Q00556E6C6F636B54696D655363616C6503213Q004661696C656420746F20756E6C6F636B3A204E6F207469636B657473206C65667403043Q007761726E030F3Q006E6F207469636B657473206C65667400214Q00887Q00203C5Q000100203C5Q0002000EA60003001A00013Q0004523Q001A00010012553Q00043Q0020345Q000500206Q000600206Q000700206Q000800206Q000900206Q000A00206Q000B00206Q000C00064Q002000013Q0004523Q002000012Q00883Q00013Q00120A0001000D8Q000200016Q00023Q00206Q000E00206Q000F00122Q000200103Q00122Q000300118Q0003000100044Q002000012Q00883Q00013Q001282000100128Q0002000100124Q00133Q00122Q000100148Q000200012Q00293Q00017Q000D3Q00032E3Q0047616D65204F7665722064657465637465642C2077616974696E6720666F722052657761726473205363722Q656E030C3Q0057616974466F724368696C6403133Q00526561637447616D654E65775265776172647303043Q007461736B03043Q0077616974026Q33D33F030E3Q0046696E6446697273744368696C6403053Q004672616D6503083Q0067616D654F766572030D3Q00526577617264735363722Q656E030E3Q005265776172647353656374696F6E03273Q0052657761726473206C6F616465642C2072657374617274696E6720696E2033207365636F6E6473026Q000840002D4Q00B87Q00122Q000100018Q000200016Q00013Q00206Q000200122Q000200038Q000200024Q00015Q001255000200043Q00203B00020002000500122Q000300066Q00020002000100202Q00023Q000700122Q000400086Q00020004000200062Q00030014000100020004523Q0014000100200E000300020007001277000500094Q001500030005000200069D00040019000100030004523Q0019000100200E0004000300070012770006000A4Q001500040006000200066A0004002100013Q0004523Q0021000100200E0005000400070012770007000B4Q001500050007000200066A0005002100013Q0004523Q002100012Q008B000100013Q00066A0001000800013Q0004523Q000800012Q008800025Q0012130003000C6Q00020002000100122Q000200043Q00202Q00020002000500122Q0003000D6Q0002000200014Q000200026Q0002000100016Q00017Q000B3Q00030C3Q0057616974466F724368696C6403173Q00526561637447616D65546F7047616D65446973706C617903053Q004672616D6503043Q007761766503093Q00636F6E7461696E657203053Q0076616C756503043Q005465787403053Q006D6174636803063Q005E2825642B2903083Q00746F6E756D626572029Q00144Q00477Q00206Q000100122Q000200028Q0002000200206Q000300206Q000400206Q000500206Q000600202Q00013Q000700202Q00010001000800122Q000300096Q00010003000200122Q0002000A6Q000300016Q00020002000200062Q00020012000100010004523Q001200010012770002000B4Q007C000200024Q00293Q00017Q00063Q0003053Q007063612Q6C03083Q00506C616365643A2003083Q00746F737472696E6703043Q007461736B03043Q0077616974026Q00D03F021C3Q001255000200013Q0006B900033Q000100032Q00888Q00503Q00014Q00508Q008E00020002000300066A0002001600013Q0004523Q001600012Q0088000400014Q0050000500034Q004900040002000200066A0004001600013Q0004523Q001600012Q0088000400023Q001257000500023Q00122Q000600036Q00078Q0006000200024Q0005000500064Q0004000200014Q000400016Q000400023Q001255000400043Q00203C000400040005001277000500064Q005D0004000200010004525Q00012Q00293Q00013Q00013Q00073Q00030C3Q00496E766F6B6553657276657203063Q0054722Q6F707303063Q00506CD0B0636503083Q00526F746174696F6E03063Q00434672616D652Q033Q006E657703083Q00506F736974696F6E000F4Q00987Q00206Q000100122Q000200023Q00122Q000300036Q00043Q000200122Q000500053Q00202Q0005000500064Q00050001000200102Q0004000400054Q000500013Q00102Q0004000700054Q000500028Q00059Q008Q00017Q00073Q0003053Q007063612Q6C03093Q0055706772616465642003083Q00746F737472696E6703043Q004E616D6503043Q007461736B03043Q0077616974026Q00D03F021C3Q001255000200013Q0006B900033Q000100032Q00888Q00508Q00503Q00014Q008E00020002000300066A0002001600013Q0004523Q001600012Q0088000400014Q0050000500034Q004900040002000200066A0004001600013Q0004523Q001600012Q0088000400023Q001203000500023Q00122Q000600033Q00202Q00073Q00044Q0006000200024Q0005000500064Q0004000200014Q000400016Q000400023Q001255000400053Q00203C000400040006001277000500074Q005D0004000200010004525Q00012Q00293Q00013Q00013Q00063Q00030C3Q00496E766F6B6553657276657203063Q0054722Q6F707303073Q00557067726164652Q033Q0053657403053Q0054722Q6F7003043Q0050617468000D4Q002E7Q00206Q000100122Q000200023Q00122Q000300033Q00122Q000400046Q00053Q00024Q000600013Q00102Q0005000500064Q000600023Q00102Q0005000600066Q00059Q008Q00017Q000A3Q00030E3Q0046696E6446697273744368696C6403103Q0048756D616E6F6964522Q6F745061727403043Q004E616D6503053Q00546F77657203053Q007063612Q6C030C3Q00536F6C6420546F7765723A2003083Q00746F737472696E6703043Q007461736B03043Q0077616974026Q00D03F01263Q00066A3Q000A00013Q0004523Q000A000100200E00013Q0001001277000300024Q001500010003000200066A0001000A00013Q0004523Q000A000100203C00013Q00030006AE0001000B000100010004523Q000B0001001277000100043Q001255000200053Q0006B900033Q000100022Q00888Q00508Q008E00020002000300066A0002002000013Q0004523Q002000012Q0088000400014Q0050000500034Q004900040002000200066A0004002000013Q0004523Q002000012Q0088000400023Q001257000500063Q00122Q000600076Q000700016Q0006000200024Q0005000500064Q0004000200014Q000400016Q000400023Q001255000400083Q00203C0004000400090012770005000A4Q005D0004000200010004523Q000B00012Q00293Q00013Q00013Q00043Q00030C3Q00496E766F6B6553657276657203063Q0054722Q6F707303043Q0053652Q6C03053Q0054722Q6F70000A4Q00BB7Q00206Q000100122Q000200023Q00122Q000300036Q00043Q00014Q000500013Q00102Q0004000400056Q00049Q008Q00017Q00083Q0003043Q007461736B03043Q0077616974026Q33D33F03053Q007063612Q6C03083Q0053652Q74696E672003043Q0020746F2003083Q00746F737472696E67026Q00D03F04293Q00066A0003000A00013Q0004523Q000A0001001255000400013Q00201800040004000200122Q000500036Q0004000200014Q00048Q00040001000200062Q00030002000100040004523Q00020001001255000400043Q0006B900053Q000100042Q00883Q00014Q00508Q00503Q00014Q00503Q00024Q008E00040002000500066A0004002300013Q0004523Q002300012Q0088000600024Q0050000700054Q004900060002000200066A0006002300013Q0004523Q002300012Q0088000600033Q001237000700056Q000800013Q00122Q000900063Q00122Q000A00076Q000B00026Q000A000200024Q00070007000A4Q0006000200014Q000600016Q000600023Q001255000600013Q00203C000600060002001277000700084Q005D0006000200010004523Q000A00012Q00293Q00013Q00013Q00073Q00030C3Q00496E766F6B6553657276657203063Q0054722Q6F707303063Q004F7074696F6E2Q033Q0053657403053Q0054722Q6F7003043Q004E616D6503053Q0056616C7565000F4Q00467Q00206Q000100122Q000200023Q00122Q000300033Q00122Q000400046Q00053Q00034Q000600013Q00102Q0005000500064Q000600023Q00102Q0005000600064Q000600033Q00102Q0005000700066Q00059Q008Q00017Q00083Q0003043Q007479706503073Q00622Q6F6C65616E03053Q007461626C65030D3Q00746F776572506F736974696F6E030C3Q00746F776572546F436C6F6E65030B3Q00746F77657254617267657403043Q007461736B03053Q00737061776E043A3Q001255000400014Q0050000500024Q004900040002000200260500040006000100020004523Q000600010004523Q000800012Q0050000300024Q0056000200023Q001255000400014Q0050000500024Q004900040002000200267D0004000F000100030004523Q000F00010006AE00020010000100010004523Q001000012Q0056000200024Q0056000400043Q00066A0002001900013Q0004523Q00190001001255000500013Q00203C0006000200042Q004900050002000200267D00050019000100030004523Q0019000100203C00040002000400069D0005001C000100020004523Q001C000100203C00050002000500069D0006001F000100020004523Q001F000100203C0006000200060006B900073Q000100092Q00503Q00024Q00503Q00044Q00503Q00054Q00888Q00503Q00064Q00883Q00014Q00508Q00503Q00014Q00883Q00023Q00066A0003003600013Q0004523Q003600012Q008B000800013Q001255000900073Q00203C0009000900080006B9000A0001000100022Q00503Q00084Q00503Q00074Q005D0009000200010006B900090002000100012Q00503Q00084Q007C000900024Q001C00086Q0050000800074Q0008000800014Q002400086Q00293Q00013Q00033Q00043Q0003053Q007063612Q6C03043Q007461736B03043Q0077616974026Q00D03F001A3Q0012553Q00013Q0006B900013Q000100082Q00888Q00883Q00014Q00883Q00024Q00883Q00034Q00883Q00044Q00883Q00054Q00883Q00064Q00883Q00074Q008E3Q0002000100066A3Q001400013Q0004523Q001400012Q0088000200084Q0050000300014Q004900020002000200066A0002001400013Q0004523Q001400012Q008B000200014Q007C000200023Q001255000200023Q00203C000200020003001277000300044Q005D0002000200010004525Q00012Q00293Q00013Q00013Q00123Q0003053Q007461626C6503053Q00636C6F6E65028Q00030D3Q00746F776572506F736974696F6E03043Q006D61746803063Q0072616E646F6D03043Q007479706503063Q006E756D626572030C3Q00746F776572546F436C6F6E65030D3Q00706C616365645F746F77657273030B3Q00746F776572546172676574030C3Q00496E766F6B6553657276657203063Q0054722Q6F707303093Q004162696C697469657303083Q00416374697661746503053Q0054722Q6F7003043Q004E616D6503043Q0044617461003B4Q008800015Q00066A0001002D00013Q0004523Q002D0001001255000100013Q002Q200001000100024Q00028Q0001000200026Q00016Q000100013Q00062Q0001001700013Q0004523Q001700012Q0088000100014Q00C2000100013Q000E3000030017000100010004523Q001700012Q0088000100013Q001235000200053Q00202Q0002000200064Q000300016Q000300036Q0002000200024Q00010001000200104Q00040001001255000100074Q0088000200024Q00490001000200020026050001001D000100080004523Q001D00010004523Q002200012Q0088000100033Q00203C00010001000A2Q0088000200024Q00960001000100020010A33Q00090001001255000100074Q0088000200044Q004900010002000200260500010028000100080004523Q002800010004523Q002D00012Q0088000100033Q00203C00010001000A2Q0088000200044Q00960001000100020010A33Q000B00012Q0088000100053Q00204D00010001000C00122Q0003000D3Q00122Q0004000E3Q00122Q0005000F6Q00063Q00034Q000700063Q00102Q0006001000074Q000700073Q00102Q00060011000700102Q000600126Q000100066Q00019Q0000017Q00033Q0003043Q007461736B03043Q0077616974026Q00F03F000B4Q00887Q00066A3Q000A00013Q0004523Q000A00012Q00883Q00014Q00193Q0001000100124Q00013Q00206Q000200122Q000100038Q0002000100046Q00012Q00293Q00019Q003Q00034Q008B8Q00878Q00293Q00017Q00103Q0003053Q004C4F2Q4259030C3Q0057616974466F724368696C64030D3Q0052656163744C6F2Q6279487564026Q003E4003053Q004672616D65030B3Q006D617463686D616B696E6703043Q0067616D65030A3Q004765745365727669636503113Q005265706C69636174656453746F72616765030E3Q0052656D6F746546756E6374696F6E03053Q007063612Q6C03213Q0053752Q63652Q7366752Q6C79206A6F696E6564206D617463686D616B696E673A2003083Q00746F737472696E6703043Q007461736B03043Q0077616974026Q00E03F02434Q008800025Q00267D00020004000100010004523Q000400010004523Q000600012Q008B00026Q007C000200024Q0088000200013Q00209400020002000200122Q000400033Q00122Q000500046Q00020005000200062Q00030011000100020004523Q0011000100200E000300020002001277000500053Q001277000600044Q001500030006000200069D00040017000100030004523Q0017000100200E000400030002001277000600063Q001277000700044Q001500040007000200066A0004004000013Q0004523Q00400001001255000500073Q0020A800050005000800122Q000700096Q00050007000200202Q00050005000200122Q0007000A6Q0005000700024Q00068Q000700073Q0012550008000B3Q0006B900093Q000100032Q00883Q00024Q00503Q00014Q00503Q00054Q008E00080002000900066A0008003900013Q0004523Q003900012Q0088000A00034Q0050000B00094Q0049000A0002000200066A000A003900013Q0004523Q003900012Q0088000A00043Q001295000B000C3Q00122Q000C000D6Q000D00016Q000C000200024Q000B000B000C4Q000A000200012Q008B000600014Q0050000700093Q0004523Q003D0001001255000A000E3Q00203C000A000A000F001277000B00104Q005D000A0002000100066A0006002200013Q0004523Q002200012Q001C00056Q008B000500014Q007C000500024Q00293Q00013Q00013Q00093Q00030F3Q006D617463686D616B696E675F6D617003043Q006D6F646503053Q00636F756E74026Q00F03F030A3Q0064692Q666963756C747903083Q00737572766976616C030C3Q00496E766F6B65536572766572030B3Q004D756C7469706C6179657203083Q0076323A7374617274001A4Q001E7Q00206Q00014Q000100019Q0000014Q000100013Q00064Q000C00013Q0004523Q000C00012Q004B00023Q00020010A3000200023Q0030680002000300042Q0050000100023Q0004523Q001200012Q004B00023Q00032Q0059000300013Q00102Q00020005000300302Q00020002000600302Q0002000300044Q000100024Q0088000200023Q00201A00020002000700122Q000400083Q00122Q000500096Q000600016Q000200066Q00029Q0000017Q00103Q00030E3Q0043752Q72656E744C6F61646F757403053Q004C4F2Q425903043Q0067616D65030A3Q004765745365727669636503113Q005265706C69636174656453746F72616765030C3Q0057616974466F724368696C64030E3Q0052656D6F746546756E6374696F6E03063Q00697061697273034Q0003053Q007063612Q6C030A3Q00457175692Q7065643A2003083Q00746F737472696E6703043Q007461736B03043Q0077616974029A5Q99C93F029A5Q99D93F013B4Q004B00026Q00AA00036Q001B00023Q00012Q008800035Q0010A30003000100022Q0088000300013Q00267D00030009000100020004523Q000900010004523Q000B00012Q008B00036Q007C000300023Q001255000300033Q00201400030003000400122Q000500056Q00030005000200202Q00030003000600122Q000500076Q00030005000200122Q000400086Q000500026Q00040002000600044Q0036000100066A0008003500013Q0004523Q0035000100260500080035000100090004523Q003500012Q008B00095Q001255000A000A3Q0006B9000B3Q000100022Q00503Q00034Q00503Q00084Q0049000A0002000200066A000A002B00013Q0004523Q002B00012Q008B000900014Q00B5000B00023Q00122Q000C000B3Q00122Q000D000C6Q000E00086Q000D000200024Q000C000C000D4Q000B0002000100044Q002F0001001255000B000D3Q00203C000B000B000E001277000C000F4Q005D000B0002000100066A0009001B00013Q0004523Q001B0001001255000A000D3Q00203C000A000A000E001277000B00104Q005D000A000200012Q001C00075Q00067E00040016000100020004523Q001600012Q008B000400014Q007C000400024Q00293Q00013Q00013Q00043Q00030C3Q00496E766F6B6553657276657203093Q00496E76656E746F727903053Q00457175697003053Q00746F77657200084Q00547Q00206Q000100122Q000200023Q00122Q000300033Q00122Q000400046Q000500018Q000500016Q00017Q000A3Q0003043Q0047414D4503843Q00682Q7470733A2Q2F6170692E6A756E6B69652D646576656C6F706D656E742E64652F6170692F76312F6C7561736372697074732F7075626C69632F3537666533393766373630343363653036616661643234663037353238633966393365392Q3733303933303234326635373133346430623630613264323530622F646F776E6C6F616403053Q007063612Q6C03043Q0067616D6503073Q00482Q7470476574030A3Q006C6F6164737472696E6703053Q00457175697003043Q007461736B03043Q0077616974029A5Q99B93F01214Q008800015Q00267D00010004000100010004523Q000400010004523Q000600012Q008B00016Q007C000100023Q001277000100023Q001248000200033Q00122Q000300043Q00202Q00030003000500122Q000400046Q000500016Q00020005000300062Q00020011000100010004523Q001100012Q008B00046Q007C000400023Q001255000400064Q0050000500034Q00490004000200022Q00110004000100012Q0088000400013Q00203C0004000400070006AE0004001E000100010004523Q001E0001001255000400083Q00203C0004000400090012770005000A4Q005D0004000200010004523Q001500012Q008B000400014Q007C000400024Q00293Q00019Q002Q0001034Q008800016Q00110001000100012Q00293Q00017Q00043Q0003043Q007461736B03043Q0077616974026Q00E03F031A3Q00412Q74656D7074696E6720746F20566F746520536B69703Q2E02103Q00066A0001000A00013Q0004523Q000A0001001255000200013Q00201800020002000200122Q000300036Q0002000200014Q00028Q00020001000200062Q00010002000100020004523Q000200012Q0088000200013Q0012C3000300046Q0002000200014Q000200026Q0002000100016Q00017Q00093Q0003043Q0047414D4503133Q0053652Q74696E672047616D6520496E666F3A2003083Q00746F737472696E67030C3Q0057616974466F724368696C6403153Q00526561637447616D65496E7465726D692Q73696F6E026Q003E4003073Q00456E61626C656403053Q004672616D65026Q00144003283Q0006AE00020004000100010004523Q000400012Q004B00036Q0050000200034Q008800035Q00267D00030008000100010004523Q000800010004523Q000A00012Q008B00036Q007C000300024Q0088000300013Q001295000400023Q00122Q000500036Q000600016Q0005000200024Q0004000400054Q0003000200012Q006F000300023Q00202Q00030003000400122Q000500053Q00122Q000600066Q00030006000200062Q0003002700013Q0004523Q0027000100203C00040003000700066A0004002700013Q0004523Q0027000100200E000400030004001277000600083Q001277000700094Q001500040007000200066A0004002700013Q0004523Q002700012Q0088000400034Q0007000500026Q0004000200014Q000400046Q000500016Q0004000200012Q00293Q00019Q002Q0001034Q008800016Q00110001000100012Q00293Q00019Q002Q0002044Q008800026Q0050000300014Q005D0002000200012Q00293Q00017Q00013Q0003103Q005374617274696E672047616D653Q2E01064Q003900015Q00122Q000200016Q0001000200014Q000100016Q0001000100016Q00017Q00013Q0003043Q0047414D4501094Q008800015Q00267D00010004000100010004523Q000400010004523Q000600012Q008B00016Q007C000100024Q0088000100014Q00110001000100012Q00293Q00019Q002Q0001044Q008800016Q0008000100014Q002400016Q00293Q00019Q002Q0001034Q008800016Q00110001000100012Q00293Q00017Q00173Q0003043Q0047414D4503063Q0069706169727303093Q00776F726B737061636503063Q00546F77657273030B3Q004765744368696C6472656E03043Q004E616D6503053Q004F776E657203053Q0056616C756503063Q005573657249642Q01030F3Q00506C6163696E6720546F7765723A2003083Q00746F737472696E6703053Q00206174202803023Q002C2003013Q002903073Q00566563746F72332Q033Q006E657703043Q007461736B03043Q0077616974029A5Q99A93F03053Q007461626C6503063Q00696E73657274030D3Q00706C616365645F746F77657273056E4Q008800055Q00267D00050004000100010004523Q000400010004523Q000600012Q008B00056Q007C000500024Q004B00055Q00122F000600023Q00122Q000700033Q00202Q00070007000400202Q0007000700054Q000700086Q00063Q000800044Q001F0001001255000B00023Q00200E000C000A00052Q0051000C000D4Q00AD000B3Q000D0004523Q001D000100203C0010000F000600267D0010001D000100070004523Q001D000100203C0010000F00082Q0088001100013Q00203C00110011000900065A0010001D000100110004523Q001D000100205C0005000A000A0004523Q001F000100067E000B0013000100020004523Q0013000100067E0006000E000100020004523Q000E00012Q0088000600023Q0012320007000B3Q00122Q0008000C6Q000900016Q00080002000200122Q0009000D3Q00122Q000A000C6Q000B00026Q000A0002000200122Q000B000E3Q00122Q000C000C6Q000D00036Q000C0002000200122Q000D000E3Q00122Q000E000C6Q000F00046Q000E0002000200122Q000F000F6Q00070007000F4Q0006000200014Q000600036Q000700013Q00122Q000800103Q00202Q0008000800114Q000900026Q000A00036Q000B00046Q0008000B6Q00063Q00014Q000600063Q001255000700023Q0012A4000800033Q00202Q00080008000400202Q0008000800054Q000800096Q00073Q000900044Q005D00012Q0096000C0005000B0006AE000C005A000100010004523Q005A0001001255000C00023Q00200E000D000B00052Q0051000D000E4Q00AD000C3Q000E0004523Q0058000100203C00110010000600267D00110058000100070004523Q0058000100203C0011001000082Q0088001200013Q00203C00120012000900065A00110058000100120004523Q005800012Q00500006000B3Q0004523Q005A000100067E000C004E000100020004523Q004E000100066A0006005D00013Q0004523Q005D00010004523Q005F000100067E00070046000100020004523Q00460001001255000700123Q00203C000700070013001277000800144Q005D00070002000100066A0006003F00013Q0004523Q003F0001001255000700153Q0020A900070007001600202Q00083Q00174Q000900066Q00070009000100202Q00073Q00174Q000700076Q000700028Q00017Q00033Q00030D3Q00706C616365645F746F77657273026Q00F03F028Q0003133Q00203C00033Q00012Q009600030003000100066A0003001200013Q0004523Q001200012Q008800046Q0050000500033Q00061700060009000100020004523Q00090001001277000600024Q008F0004000600012Q0088000400014Q0088000500014Q00960005000500010006AE00050010000100010004523Q00100001001277000500033Q00205E0005000500022Q006C0004000100052Q00293Q00017Q00053Q0003043Q007461736B03043Q0077616974026Q00E03F030D3Q00706C616365645F746F7765727303053Q007063612Q6C04173Q00066A0003000A00013Q0004523Q000A0001001255000400013Q00201800040004000200122Q000500036Q0004000200014Q00048Q00040001000200062Q00030002000100040004523Q0002000100203C00043Q00042Q00960004000400010006AE0004000F000100010004523Q000F00012Q00293Q00013Q001255000500053Q0006B900063Q000100042Q00883Q00014Q00503Q00044Q00503Q00024Q00883Q00024Q005D0005000200012Q00293Q00013Q00013Q00093Q00030C3Q00496E766F6B6553657276657203063Q0054722Q6F707303063Q005461726765742Q033Q0053657403053Q0054722Q6F70030C3Q00536574205461726765743A2003083Q00746F737472696E6703043Q004E616D6503043Q00202D3E2000184Q00807Q00206Q000100122Q000200023Q00122Q000300033Q00122Q000400046Q00053Q00024Q000600013Q00102Q0005000500064Q000600023Q00102Q0005000300066Q000500016Q00033Q00122Q000100063Q00122Q000200076Q000300013Q00202Q0003000300084Q00020002000200122Q000300093Q00122Q000400076Q000500026Q0004000200024Q0001000100046Q000200016Q00017Q00093Q0003043Q007461736B03043Q0077616974026Q00E03F030D3Q00706C616365645F746F7765727303063Q00536F6C643A2003083Q00746F737472696E6703043Q004E616D6503053Q007461626C6503063Q0072656D6F766503243Q00066A0002000A00013Q0004523Q000A0001001255000300013Q00201800030003000200122Q000400036Q0003000200014Q00038Q00030001000200062Q00020002000100030004523Q0002000100203C00033Q00042Q009600030003000100066A0003002100013Q0004523Q002100012Q0088000400014Q0050000500034Q004900040002000200066A0004002100013Q0004523Q002100012Q0088000400023Q00129A000500053Q00122Q000600063Q00202Q0007000300074Q0006000200024Q0005000500064Q00040002000100122Q000400083Q00202Q00040004000900202Q00053Q00044Q000600016Q0004000600014Q000400016Q000400024Q008B00046Q007C000400024Q00293Q00017Q000A3Q0003043Q007461736B03043Q0077616974026Q00E03F03063Q00756E7061636B030D3Q00706C616365645F746F7765727303063Q0069706169727303063Q00536F6C643A2003043Q004E616D6503053Q007461626C6503063Q0072656D6F766502313Q00066A0001000A00013Q0004523Q000A0001001255000200013Q00201800020002000200122Q000300036Q0002000200014Q00028Q00020001000200062Q00010002000100020004523Q000200012Q004B00025Q001255000300043Q00203C00043Q00052Q0051000300044Q001B00023Q0001001255000300064Q0050000400024Q008E0003000200050004523Q002C00012Q0088000800014Q0050000900074Q004900080002000200066A0008002C00013Q0004523Q002C0001001255000800063Q00203C00093Q00052Q008E00080002000A0004523Q002A00010006C1000C001F000100070004523Q001F00010004523Q002A00012Q0088000D00023Q001281000E00073Q00202Q000F000700084Q000E000E000F4Q000D0002000100122Q000D00093Q00202Q000D000D000A00202Q000E3Q00054Q000F000B6Q000D000F000100044Q002C000100067E0008001C000100020004523Q001C000100067E00030013000100020004523Q001300012Q008B000300014Q007C000300024Q00293Q00017Q00013Q00030D3Q00706C616365645F746F77657273050E3Q00203C00053Q00012Q00960005000500010006AE00050006000100010004523Q000600012Q008B00066Q007C000600024Q008800066Q0092000700056Q000800026Q000900036Q000A00046Q0006000A6Q00066Q00293Q00017Q00033Q00028Q0003043Q007461736B03053Q00737061776E01174Q004B00026Q00AA00036Q001B00023Q00012Q00C2000300023Q00260500030007000100010004523Q000700010004523Q000800012Q00293Q00014Q008B000300013Q001255000400023Q00203C0004000400030006B900053Q000100062Q00503Q00034Q00503Q00024Q00888Q00883Q00014Q00883Q00024Q00883Q00034Q005D0004000200010006B900040001000100012Q00503Q00034Q007C000400024Q00293Q00013Q00023Q000E3Q00026Q00F03F030D3Q00706C616365645F746F7765727303243Q0041637469766174696E67204162696C6974793A2043612Q6C204F662041726D73206F6E2003043Q004E616D65030C3Q0043612Q6C204F662041726D7303143Q005265616374556E6976657273616C486F7462617203053Q004672616D65030E3Q0046696E6446697273744368696C6403093Q0074696D657363616C6503043Q004C6F636B03043Q007461736B03043Q0077616974026Q002540026Q00164000383Q0012773Q00014Q008800015Q00066A0001003700013Q0004523Q003700012Q0088000100014Q0025000100016Q000200023Q00202Q0002000200024Q00020002000100062Q0002001400013Q0004523Q001400012Q0088000300033Q00125B000400033Q00202Q0005000200044Q0004000400054Q0003000200014Q000300046Q000400023Q00122Q000500056Q0003000500012Q0088000300053Q0020BD00030003000600202Q00030003000700202Q00040003000800122Q000600096Q00040006000200062Q0004002B00013Q0004523Q002B000100200E0005000400080012770007000A4Q001500050007000200066A0005002600013Q0004523Q002600010012550005000B3Q00203C00050005000C0012770006000D4Q005D0005000200010004523Q002F00010012550005000B3Q00203C00050005000C0012770006000E4Q005D0005000200010004523Q002F00010012550005000B3Q00203C00050005000C0012770006000D4Q005D00050002000100205E5Q00012Q0088000500014Q00C2000500053Q0006BF3Q0035000100050004523Q003500010004523Q000100010012773Q00013Q0004523Q000100012Q00293Q00019Q003Q00034Q008B8Q00878Q00293Q00017Q00013Q00030D3Q00706C616365645F746F77657273050E3Q00203C00053Q00012Q009600050005000100066A0005000B00013Q0004523Q000B00012Q008800066Q0092000700056Q000800026Q000900036Q000A00046Q0006000A6Q00066Q008B00066Q007C000600024Q00293Q00017Q00053Q0003043Q006D6174682Q033Q0061627303083Q00506F736974696F6E03013Q0059024Q007E842E41010B3Q001238000100013Q00202Q00010001000200202Q00023Q000300202Q0002000200044Q000100020002000E2Q00050008000100010004523Q000800012Q000200016Q008B000100014Q007C000100024Q00293Q00017Q00033Q0003093Q00436861726163746572030E3Q0046696E6446697273744368696C6403103Q0048756D616E6F6964522Q6F745061727400094Q00887Q00203C5Q000100069D0001000700013Q0004523Q0007000100200E00013Q0002001277000300034Q00150001000300022Q007C000100024Q00293Q00017Q00033Q00030B3Q004175746F5069636B75707303043Q007461736B03053Q00737061776E00144Q00887Q0006AE3Q0007000100010004523Q000700012Q00883Q00013Q00203C5Q00010006AE3Q0008000100010004523Q000800012Q00293Q00014Q008B3Q00014Q00877Q0012553Q00023Q00203C5Q00030006B900013Q000100052Q00883Q00014Q00883Q00024Q00883Q00034Q00883Q00044Q00888Q005D3Q000200012Q00293Q00013Q00013Q00163Q00030B3Q004175746F5069636B75707303093Q00776F726B7370616365030E3Q0046696E6446697273744368696C6403073Q005069636B75707303063Q00697061697273030B3Q004765744368696C6472656E2Q033Q0049734103083Q004D6573685061727403043Q004E616D6503093Q00536E6F77436861726D03083Q004C6F7265622Q6F6B03113Q00436F2Q6C656374696E67204974656D3A2003083Q00746F737472696E6703063Q00434672616D652Q033Q006E6577028Q00026Q00084003043Q007461736B03043Q0077616974029A5Q99C93F026Q33D33F026Q00F03F004C4Q00887Q00203C5Q000100066A3Q004900013Q0004523Q004900010012553Q00023Q0020725Q000300122Q000200048Q000200024Q000100016Q00010001000200064Q004400013Q0004523Q0044000100066A0001004400013Q0004523Q00440001001255000200053Q00200E00033Q00062Q0051000300044Q00AD00023Q00040004523Q004200012Q008800075Q00203C0007000700010006AE00070018000100010004523Q001800010004523Q0044000100200E000700060007001277000900084Q001500070009000200066A0007004200013Q0004523Q0042000100203C000700060009002605000700230001000A0004523Q0023000100203C00070006000900267D000700420001000B0004523Q004200012Q0088000700024Q0050000800064Q00490007000200020006AE00070042000100010004523Q004200012Q0088000700033Q00125F0008000C3Q00122Q0009000D3Q00202Q000A000600094Q0009000200024Q0008000800094Q00070002000100202Q00070001000E00202Q00080006000E00122Q0009000E3Q00202Q00090009000F00122Q000A00103Q00122Q000B00113Q00122Q000C00106Q0009000C00024Q00080008000900102Q0001000E000800122Q000800123Q00202Q00080008001300122Q000900146Q00080002000100102Q0001000E000700122Q000800123Q00202Q00080008001300122Q000900156Q00080002000100067E00020013000100020004523Q00130001001255000200123Q00203C000200020013001277000300164Q005D0002000200010004525Q00012Q008B8Q00873Q00044Q00293Q00017Q00033Q0003083Q004175746F536B697003043Q007461736B03053Q00737061776E00144Q00887Q0006AE3Q0007000100010004523Q000700012Q00883Q00013Q00203C5Q00010006AE3Q0008000100010004523Q000800012Q00293Q00014Q008B3Q00014Q00877Q0012553Q00023Q00203C5Q00030006B900013Q000100052Q00883Q00014Q00883Q00024Q00883Q00034Q00883Q00044Q00888Q005D3Q000200012Q00293Q00013Q00013Q000F3Q0003083Q004175746F536B6970030E3Q0046696E6446697273744368696C6403123Q0052656163744F76652Q7269646573566F746503053Q004672616D6503053Q00766F74657303043Q00766F746503083Q00506F736974696F6E03053Q005544696D322Q033Q006E6577026Q00E03F028Q0003133Q004175746F2D536B6970205472692Q676572656403043Q007461736B03043Q0077616974026Q00F03F00394Q00887Q00203C5Q000100066A3Q003600013Q0004523Q003600012Q00883Q00013Q00200E5Q0002001277000200034Q00153Q0002000200066A3Q002000013Q0004523Q002000012Q00883Q00013Q0020B15Q000300206Q000200122Q000200048Q0002000200064Q002000013Q0004523Q002000012Q00883Q00013Q0020BD5Q000300206Q000400206Q000200122Q000200058Q0002000200064Q002000013Q0004523Q002000012Q00883Q00013Q00200C5Q000300206Q000400206Q000500206Q000200122Q000200068Q0002000200066A3Q003100013Q0004523Q0031000100203C00013Q0007001231000200083Q00202Q00020002000900122Q0003000A3Q00122Q0004000B3Q00122Q0005000A3Q00122Q0006000B6Q00020006000200062Q00010031000100020004523Q003100012Q0088000100023Q0012770002000C4Q005D0001000200012Q0088000100034Q00110001000100010012550001000D3Q00203C00010001000E0012770002000F4Q005D0001000200010004525Q00012Q008B8Q00873Q00044Q00293Q00017Q00023Q0003043Q007461736B03053Q00737061776E000D4Q00887Q00066A3Q000400013Q0004523Q000400012Q00293Q00014Q008B3Q00014Q00877Q0012553Q00013Q00203C5Q00020006B900013Q000100022Q00883Q00014Q00888Q005D3Q000200012Q00293Q00013Q00013Q00043Q0003053Q007063612Q6C03043Q007461736B03043Q0077616974026Q001440000C3Q0012553Q00013Q0006B900013Q000100012Q00888Q006D3Q0002000100124Q00023Q00206Q000300122Q000100048Q0002000100046Q00012Q008B8Q00873Q00014Q00293Q00013Q00018Q00034Q00888Q00113Q000100012Q00293Q00017Q00023Q0003043Q007461736B03053Q00737061776E000D4Q00887Q00066A3Q000400013Q0004523Q000400012Q00293Q00014Q008B3Q00014Q00877Q0012553Q00013Q00203C5Q00020006B900013Q000100022Q00883Q00014Q00888Q005D3Q000200012Q00293Q00013Q00013Q000F3Q0003073Q00416E74694C616703093Q00776F726B7370616365030E3Q0046696E6446697273744368696C6403063Q00546F77657273030B3Q00436C69656E74556E69747303043Q004E50437303063Q00697061697273030B3Q004765744368696C6472656E030A3Q00416E696D6174696F6E7303063Q00576561706F6E030B3Q0050726F6A656374696C657303073Q0044657374726F7903043Q007461736B03043Q0077616974026Q00E03F004C4Q00887Q00203C5Q000100066A3Q004900013Q0004523Q004900010012553Q00023Q0020715Q000300122Q000200048Q0002000200122Q000100023Q00202Q00010001000300122Q000300056Q00010003000200122Q000200023Q00202Q00020002000300122Q000400066Q00020004000200064Q002E00013Q0004523Q002E0001001255000300073Q00200E00043Q00082Q0051000400054Q00AD00033Q00050004523Q002C000100200E000800070003001274000A00096Q0008000A000200202Q00090007000300122Q000B000A6Q0009000B000200202Q000A0007000300122Q000C000B6Q000A000C000200062Q0008002400013Q0004523Q0024000100200E000B0008000C2Q005D000B0002000100066A000A002800013Q0004523Q0028000100200E000B000A000C2Q005D000B0002000100066A0009002C00013Q0004523Q002C000100200E000B0009000C2Q005D000B0002000100067E00030017000100020004523Q0017000100066A0001003900013Q0004523Q00390001001255000300073Q00200E0004000100082Q0051000400054Q00AD00033Q00050004523Q0037000100200E00080007000C2Q005D00080002000100067E00030035000100020004523Q0035000100066A0002004400013Q0004523Q00440001001255000300073Q00200E0004000200082Q0051000400054Q00AD00033Q00050004523Q0042000100200E00080007000C2Q005D00080002000100067E00030040000100020004523Q004000010012550003000D3Q00203C00030003000E0012770004000F4Q005D0003000200010004525Q00012Q008B8Q00873Q00014Q00293Q00017Q000B3Q0003043Q0067616D65030A3Q004765745365727669636503073Q00506C6179657273030E3Q00676574636F2Q6E656374696F6E73030F3Q006765745F7369676E616C5F636F6E7303053Q007061697273030B3Q004C6F63616C506C6179657203053Q0049646C656403073Q0044697361626C65030A3Q00446973636F2Q6E65637403073Q00436F2Q6E656374002D3Q0012273Q00013Q00206Q000200122Q000200038Q0002000200122Q000100043Q00062Q0001000A00013Q0004523Q000A0001001255000100043Q0006AE0001000B000100010004523Q000B0001001255000100053Q00066A0001002200013Q0004523Q00220001001255000200064Q009C000300013Q00202Q00043Q000700202Q0004000400084Q000300046Q00023Q000400044Q001F000100203C00070006000900066A0007001A00013Q0004523Q001A000100200E0007000600092Q005D0007000200010004523Q001F000100203C00070006000A00066A0007001F00013Q0004523Q001F000100200E00070006000A2Q005D00070002000100067E00020014000100020004523Q001400010004523Q0027000100203C00023Q000700203C00020002000800200E00020002000B00026700046Q008F00020004000100203C00023Q000700203C00020002000800200E00020002000B000267000400014Q00150002000400022Q00293Q00013Q00023Q00073Q0003043Q0067616D65030A3Q0047657453657276696365030B3Q005669727475616C5573657203113Q0043617074757265436F6E74726F2Q6C6572030C3Q00436C69636B42752Q746F6E3203073Q00566563746F72322Q033Q006E6577000C3Q00123E3Q00013Q00206Q000200122Q000200038Q0002000200202Q00013Q00044Q00010002000100202Q00013Q000500122Q000300063Q00202Q0003000300074Q000300016Q00013Q00016Q00017Q000E3Q0003043Q0067616D65030A3Q0047657453657276696365030B3Q005669727475616C55736572030B3Q0042752Q746F6E32446F776E03073Q00566563746F72322Q033Q006E6577028Q0003093Q00776F726B7370616365030D3Q0043752Q72656E7443616D65726103063Q00434672616D6503043Q007461736B03043Q0077616974026Q00F03F03093Q0042752Q746F6E325570001D3Q00121D3Q00013Q00206Q000200122Q000200038Q0002000200202Q00013Q000400122Q000300053Q00202Q00030003000600122Q000400073Q00122Q000500076Q00030005000200122Q000400083Q00202Q00040004000900202Q00040004000A4Q00010004000100122Q0001000B3Q00202Q00010001000C00122Q0002000D6Q00010002000100202Q00013Q000E00122Q000300053Q00202Q00030003000600122Q000400073Q00122Q000500076Q00030005000200122Q000400083Q00202Q00040004000900202Q00040004000A4Q0001000400016Q00017Q00023Q0003043Q007461736B03053Q00737061776E00053Q0012553Q00013Q00203C5Q000200026700016Q005D3Q000200012Q00293Q00013Q00013Q00043Q0003043Q0067616D6503073Q00506C6179657273030E3Q00506C6179657252656D6F76696E6703073Q00636F2Q6E65637400073Q0012553Q00013Q00203C5Q000200203C5Q000300200E5Q000400026700026Q008F3Q000200012Q00293Q00013Q00013Q00073Q0003043Q0067616D6503073Q00506C6179657273030B3Q004C6F63616C506C61796572030A3Q0047657453657276696365030F3Q0054656C65706F72745365727669636503083Q0054656C65706F7274022Q00E01E154BE841010F3Q001255000100013Q00203C00010001000200203C0001000100030006C13Q0006000100010004523Q000600010004523Q000E0001001255000100013Q00208400010001000400122Q000300056Q00010003000200202Q00010001000600122Q000300076Q00048Q0001000400012Q00293Q00017Q000B3Q0003053Q007063612Q6C03043Q0067616D6503073Q00482Q747047657403083Q006D6163726F55524C03073Q0067657467656E762Q033Q00544453030A3Q006C6F6164737472696E6703043Q007761726E03193Q004661696C656420746F20636F6D70696C65206D6163726F3A2003083Q00746F737472696E67031A3Q004661696C656420746F20646F776E6C6F6164206D6163726F3A2000253Q0012AC3Q00013Q00122Q000100023Q00202Q00010001000300122Q000200026Q00035Q00202Q0003000300046Q0003000100064Q001D00013Q0004523Q001D0001001255000200054Q00830002000100024Q000300013Q00102Q00020006000300122Q000200076Q000300016Q00020002000300062Q0002001500013Q0004523Q001500012Q0050000400024Q00110004000100010004523Q00240001001255000400083Q0012A7000500093Q00122Q0006000A6Q000700036Q0006000200024Q0005000500064Q00040002000100044Q00240001001255000200083Q0012950003000B3Q00122Q0004000A6Q000500016Q0004000200024Q0003000300044Q0002000200012Q00293Q00017Q00", GetFEnv(), ...);
