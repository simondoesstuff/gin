run *args='-h':
	cargo run --release --bin gin -- {{args}}

bench:
	cargo bench

test:
	cargo test
