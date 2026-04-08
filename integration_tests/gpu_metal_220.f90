program gpu_metal_220
! Test struct-to-struct copy in do concurrent for arrays of derived types
! with allocatable members. The Metal backend must deep-copy allocatable
! member data through decomposed buffers instead of shallow struct copy.
implicit none
type :: t
    real, allocatable :: v(:)
end type
integer, parameter :: n = 4
type(t) :: a(n), b(n)
integer :: i

do i = 1, n
    allocate(a(i)%v(3))
    a(i)%v = [real :: i, i + 10, i + 100]
    allocate(b(i)%v(3))
    b(i)%v = 0.0
end do

do concurrent(i = 1:n)
    b(i) = a(i)
end do

do i = 1, n
    if (b(i)%v(1) /= real(i)) error stop
    if (b(i)%v(2) /= real(i + 10)) error stop
    if (b(i)%v(3) /= real(i + 100)) error stop
end do
print *, "PASS"
end program
