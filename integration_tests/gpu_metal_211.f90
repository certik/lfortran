program gpu_metal_211
implicit none
integer :: i
real :: z(3, 3), a(3, 3)

z = 0.1
a = 0.0

do concurrent (i = 1:3)
    a(1:3, i) = -z(1:3, i)
end do

print *, a(1, 1)
if (abs(a(1, 1) - (-0.1)) > 1e-6) error stop
print *, a(2, 3)
if (abs(a(2, 3) - (-0.1)) > 1e-6) error stop
print *, "ok"
end program
