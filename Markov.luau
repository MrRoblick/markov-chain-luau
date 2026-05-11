--!strict
--!optimize 2
const Markov = {}

export type Tokenizer = (string) -> {string}
const DefaultTokenizer: Tokenizer = @[native, checked] function(Text: string): {string}
	const Words = {}
	for word in Text:gmatch("%S+") do
		word = word:gsub("^[%p]+", ""):gsub("[%p]+$", "")
		if #word > 0 then
			table.insert(Words, word)
		end
	end
	return Words
end

const UPPER_TO_LOWER: {[string]: string} = {} do
	const Upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
	const Lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
	for i = 1, utf8.len(Upper) :: number do
		const UpperChar = utf8.char(utf8.codepoint(Upper, utf8.offset(Upper, i)))
		const LowerChar = utf8.char(utf8.codepoint(Lower, utf8.offset(Lower, i)))
		UPPER_TO_LOWER[UpperChar] = LowerChar
	end
	table.freeze(UPPER_TO_LOWER)
end
@[native, checked] const function char_lower(Character: string): string
	return UPPER_TO_LOWER[Character] or Character:lower()
end

@[native, checked] const function utf8_lower(Text: string): string
	const Result = string.gsub(Text, utf8.charpattern, char_lower)
	return Result
end


const __class = {} do
	@[native, checked] function __class.Train(self: Markov, Text: string, Tokenizer: Tokenizer?, CaseSensitive: boolean?): ()
		if not CaseSensitive then Text = utf8_lower(Text) end
		const Words = if Tokenizer then Tokenizer(Text) else DefaultTokenizer(Text)
		
		for i = 1, #Words - 1 do
			const CurrentWord = Words[i]
			const NextWord = Words[i + 1]
			
			if not self.Map[CurrentWord] then
				self.Map[CurrentWord] = {}
			end
			
			table.insert(self.Map[CurrentWord], NextWord)
		end
	end
	@[native, checked] function __class.Generate(self: Markov, StartWord: string, Limit: number, Rand: Random, CaseSensitive: boolean?): string
		if not CaseSensitive then StartWord = utf8_lower(StartWord) end
		const Result = {StartWord}
		local CurrentWord = StartWord
		for i = 1, Limit do
			const Possibilities = self.Map[CurrentWord]
			if Possibilities and #Possibilities > 0 then
				const NextWord = Possibilities[Rand:NextInteger(1, #Possibilities)]
				table.insert(Result, NextWord)
				CurrentWord = NextWord
			else
				break
			end
		end
		return table.concat(Result, " ")
	end
	@[native, checked] function __class.GetWords(self: Markov): {string}
		const Keys = {}
		for k in self.Map do table.insert(Keys, k) end
		return Keys
	end
	@[native, checked] function __class.GetMap(self: Markov): {[string]: {string}}
		return self.Map
	end
	table.freeze(__class)
end

const __meta = table.freeze({__index=__class})
export type Markov = setmetatable<{
	read Map: {[string]: {string}}	
}, typeof(__meta)>

@checked function Markov.new(Map: {[string]: {string}}?): Markov
	return table.freeze(setmetatable({
		Map = Map or {}
	}, __meta))
end

@[native, checked] function Markov.SerializeMap(Map: {[string]: {string}}): buffer
	const StringToIdx: {[string]: number} = {}
	const Strings: {string} = {}
	local StringCount = 0

	@[native, checked] const function InternString(String: string): number
		local Idx = StringToIdx[String]
		if not Idx then
			StringCount += 1
			Idx = StringCount
			StringToIdx[String] = Idx
			Strings[Idx] = String
		end
		return Idx
	end

	local KeyCount = 0
	const KeyList: {string} = {}
	for Key, Words in Map do
		KeyCount += 1
		KeyList[KeyCount] = Key
		InternString(Key)
		for _, Word in Words do
			InternString(Word)
		end
	end

	local TotalSize = 4 -- u32 string_count
	for _, S in Strings do
		const Len = #S
		if Len > 0xFFFF then error(`String too long: "{S}"`) end
		TotalSize += 2 + Len -- u16 len + bytes
	end
	TotalSize += 4 -- u32 key_count
	for _, Key in KeyList do
		TotalSize += 4 -- u32 key_idx
		TotalSize += 4 -- u32 word_count
		TotalSize += #Map[Key] * 4 -- u32 word_idx per word
	end

	const Buf = buffer.create(TotalSize)
	local Cursor = 0

	buffer.writeu32(Buf, Cursor, StringCount)
	Cursor += 4
	for _, S in Strings do
		const Len = #S
		buffer.writeu16(Buf, Cursor, Len)
		Cursor += 2
		buffer.writestring(Buf, Cursor, S)
		Cursor += Len
	end

	buffer.writeu32(Buf, Cursor, KeyCount)
	Cursor += 4
	for _, Key in KeyList do
		buffer.writeu32(Buf, Cursor, StringToIdx[Key] - 1)
		Cursor += 4
		const Words = Map[Key]
		const WordCount = #Words
		buffer.writeu32(Buf, Cursor, WordCount)
		Cursor += 4
		for _, Word in Words do
			buffer.writeu32(Buf, Cursor, StringToIdx[Word] - 1)
			Cursor += 4
		end
	end

	return Buf
end

@[native, checked] function Markov.DeserializeMap(Buf: buffer): {[string]: {string}}
	local Cursor = 0

	const StringCount = buffer.readu32(Buf, Cursor)
	Cursor += 4
	const Strings = table.create(StringCount) :: {string}
	for i = 1, StringCount do
		const Len = buffer.readu16(Buf, Cursor)
		Cursor += 2
		Strings[i] = buffer.readstring(Buf, Cursor, Len)
		Cursor += Len
	end

	const KeyCount = buffer.readu32(Buf, Cursor)
	Cursor += 4
	local Map: {[string]: {string}} = {}
	for _ = 1, KeyCount do
		const Key = Strings[buffer.readu32(Buf, Cursor) + 1]
		Cursor += 4
		const WordCount = buffer.readu32(Buf, Cursor)
		Cursor += 4
		const Words = table.create(WordCount) :: {string}
		for j = 1, WordCount do
			Words[j] = Strings[buffer.readu32(Buf, Cursor) + 1]
			Cursor += 4
		end
		Map[Key] = Words
	end

	return Map
end

Markov.DefaultTokenizer = DefaultTokenizer

return table.freeze(Markov)
