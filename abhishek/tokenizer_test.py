from transformers import AutoTokenizer


tokenizer = AutoTokenizer.from_pretrained("./trained_tokenizer")


text = ["hello, world!"]
encoded = tokenizer.batch_encode_plus(text)
print(encoded)
