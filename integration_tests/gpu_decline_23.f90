! gpu decline reason: LiveoutDerivedType
! An allocatable scalar component the loop defines, which a thread cannot
! keep a private copy of: whether it is allocated after the loop depends
! on the iterations.
module gpu_decline_23_m
    implicit none
    type :: u
        integer, allocatable :: k
        integer :: n
    end type
end module

program gpu_decline_23
    use gpu_decline_23_m
    implicit none
    type(u) :: y
    integer :: i, a(100)
    y%n = 0
    do concurrent (i = 1:100)
        a(i) = i
        if (i == 3) y%k = 7
    end do
    print *, y%k
    if (y%k /= 7) error stop 1
    if (a(100) /= 100) error stop 2
end program
