! With --gpu-memory=unified a kernel reads and writes the host's own
! storage, so the host has to wait before it changes or frees anything a
! pending launch only reads, too. Each section below changes or frees such
! storage right after the launch.
module gpu_unified_memory_01_m
    implicit none
    integer, parameter :: n = 1000000
    real :: module_data(n)
    type :: holder_t
        real, allocatable :: v(:)
    end type
contains
    subroutine smooth(u, w)
        real, intent(in) :: u(:)
        real, intent(inout) :: w(:)
        integer :: i
        do concurrent (i = 2:size(u) - 1)
            w(i) = 0.25*u(i - 1) + 0.5*u(i) + 0.25*u(i + 1)
        end do
    end subroutine

    subroutine automatic(m, out)
        integer, intent(in) :: m
        real, intent(out) :: out(m)
        real :: local(m)
        integer :: i
        local = 3
        do concurrent (i = 1:m)
            out(i) = local(i) + 1
        end do
    end subroutine
end module

program gpu_unified_memory_01
    use gpu_unified_memory_01_m
    implicit none
    real, allocatable :: a(:), b(:), c(:, :)
    real, save :: saved(n)
    type(holder_t) :: h(4)
    real :: d(n)
    integer :: i, s

    ! Kernels in a called procedure, one after another.
    allocate(a(n), b(n))
    a = 1
    b = 1
    do s = 1, 10
        call smooth(a, b)
        call smooth(b, a)
    end do
    if (any(abs(a - 1) > 1e-6) .or. any(abs(b - 1) > 1e-6)) error stop 1

    ! The host writes what the kernel only reads.
    do concurrent (i = 1:n)
        b(i) = 2*a(i)
    end do
    a = -1
    if (any(abs(b - 2) > 1e-6)) error stop 2

    ! The host frees what the kernel only reads.
    a = 5
    do concurrent (i = 1:n)
        b(i) = a(i) + 1
    end do
    deallocate(a)
    if (any(abs(b - 6) > 1e-6)) error stop 3

    ! Module, saved and stack storage.
    module_data = 7
    do concurrent (i = 1:n)
        saved(i) = module_data(i) + 1
    end do
    do concurrent (i = 1:n)
        d(i) = saved(i) + 1
    end do
    module_data = 0
    saved = 0
    if (any(abs(d - 9) > 1e-6)) error stop 4
    call automatic(n, b)
    if (any(abs(b - 4) > 1e-6)) error stop 5

    ! A strided section, which the host copies for the launch.
    allocate(c(2, n))
    c = 1
    call smooth(c(1, :), b)
    if (any(abs(b(2:n - 1) - 1) > 1e-6)) error stop 6

    ! The components of an array of derived type, which the host copies
    ! for the launch as well.
    do s = 1, size(h)
        allocate(h(s)%v(1000))
        h(s)%v = s
    end do
    do concurrent (s = 1:size(h))
        d(s) = h(s)%v(1000) + 1
    end do
    if (any(abs(d(1:4) - [2, 3, 4, 5]) > 1e-6)) error stop 7
    print *, "ok"
end program
