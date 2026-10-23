! gpu decline reason: LiveoutDerivedType
! A derived-type variable the loop assigns whole and then reads, whose
! value is too large for each thread to keep a private copy of.
module gpu_decline_24_m
    implicit none
    type :: big
        real :: c(1000)
        integer :: k
    end type
end module

program gpu_decline_24
    use gpu_decline_24_m
    implicit none
    type(big) :: z
    integer :: i, a(100)
    do concurrent (i = 1:100)
        z = big(real(i), i)
        a(i) = z%k
    end do
    z%k = 0
    print *, a(100), z%k
    if (a(100) /= 100) error stop 1
end program
