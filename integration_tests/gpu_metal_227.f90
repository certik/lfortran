! Test: do concurrent with array constructor of derived types containing
! allocatable components offloaded to GPU. Verifies that allocatable
! sub-member data is deep-copied when assigning device struct array
! elements to kernel-local array constructor temps.
program gpu_metal_227
  implicit none
  type :: inner_t
    real, allocatable :: v(:)
  end type
  type :: outer_t
    type(inner_t), allocatable :: items(:)
  end type

  integer, parameter :: n = 2
  type(inner_t) :: a(n)
  type(outer_t) :: b(n)
  integer :: i

  do i = 1, n
    allocate(a(i)%v(1))
    a(i)%v(1) = real(i)
  end do

  do concurrent(i = 1:n)
    b(i) = make_outer([a(i)])
  end do

  if (size(b(1)%items) /= 1) error stop
  if (size(b(2)%items) /= 1) error stop
  if (abs(b(1)%items(1)%v(1) - 1.0) > 0.001) error stop
  if (abs(b(2)%items(1)%v(1) - 2.0) > 0.001) error stop
  print *, "ok"

contains
  pure function make_outer(items) result(o)
    type(inner_t), intent(in) :: items(:)
    type(outer_t) :: o
    o%items = items
  end function
end program
