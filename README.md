Example:
```luau
const EncodingService = game:GetService('EncodingService')
const Markov = require("@self/Markov")
const Chain = Markov.new()
const Generator = Random.new()

Chain:Train("кот сидел на окне и кот смотрел на птиц")
print(Chain:Generate("кот", 5, Generator))
print(Chain:GetWords())

const Serialized = Markov.SerializeMap(Chain:GetMap())
print(buffer.len(Serialized))

const Deserialized = Markov.DeserializeMap(Serialized)
print(Deserialized)

const Compressed = EncodingService:CompressBuffer(Serialized, Enum.CompressionAlgorithm.Zstd, 22)
print(buffer.len(Compressed))
```
