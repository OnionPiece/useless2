print "print Ctrl+X to exit input..."
a = raw_input()
input_list = []
while a != '\x18':
    a = a.strip()
    if a.startswith('0x0'):
        input_list.extend(a.split()[1:])
    a = raw_input()

print ''.join(input_list)
