program gpu_metal_252
! Test: do concurrent GPU offloading with elemental function returning
! derived type containing nested allocatable components.
implicit none

type :: val_t
  real, allocatable :: v(:)
end type

type :: pair_t
  type(val_t) :: a
end type

type :: wrap_t
  type(pair_t), allocatable :: pairs(:)
end type

integer, parameter :: n = 4
type(val_t), allocatable :: xs(:,:)
type(wrap_t), allocatable :: ws(:)
integer :: j

allocate(xs(1, n))
do j = 1, n
  xs(1,j)%v = [real(j)]
end do

allocate(ws(n))
do concurrent(j = 1:n)
  ws(j) = mk_wrap(mk_pair(xs(:,j)))
end do

do j = 1, n
  if (size(ws(j)%pairs) /= 1) error stop
  if (abs(ws(j)%pairs(1)%a%v(1) - real(j)) > 0.001) error stop
end do

print *, "PASS"

contains

elemental function mk_pair(x) result(p)
  type(val_t), intent(in) :: x
  type(pair_t) :: p
  p%a = x
end function

pure function mk_wrap(pairs) result(w)
  type(pair_t), intent(in) :: pairs(:)
  type(wrap_t) :: w
  w%pairs = pairs
end function

end program
