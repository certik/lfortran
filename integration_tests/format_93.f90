program format_93
! Test that T/TL edit descriptors preserve characters beyond the new
! write position (Fortran standard section 13.8.1.2).
implicit none
character(len=20) :: buf

! Test 1: TL overwrites only the specified positions
buf = ' '
write(buf, '(A5,TL5,A3)') 'ABCDE', 'XYZ'
if (buf(1:5) /= 'XYZDE') error stop "Test 1 failed"

! Test 2: TL with partial overwrite in the middle
buf = ' '
write(buf, '(A6,TL4,A2)') 'ABCDEF', 'XY'
if (buf(1:6) /= 'ABXYEF') error stop "Test 2 failed"

! Test 3: T (absolute tab) moving backwards
buf = ' '
write(buf, '(A5,T2,A2)') 'ABCDE', 'XY'
if (buf(1:5) /= 'AXYDE') error stop "Test 3 failed"

! Test 4: TL moves all the way to position 1
buf = ' '
write(buf, '(A3,TL3,A1)') 'ABC', 'X'
if (buf(1:3) /= 'XBC') error stop "Test 4 failed"

! Test 5: Multiple TL moves
buf = ' '
write(buf, '(A5,TL5,A1,TL1,A1)') 'ABCDE', 'X', 'Y'
if (buf(1:5) /= 'YBCDE') error stop "Test 5 failed"

print *, "PASS"
end program
