make:
	as -g --32 memos.s -o memos.o
	ld -g -T memlayout.ld memos.o -o memos
	objcopy -O binary memos bootloader.bin

clean:
	rm -f memos.o
	rm -f memos
	rm -f bootloader.bin


