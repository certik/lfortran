! Test: elemental function returning derived type with allocatable
! component inside do concurrent with allocatable output array.
! Verifies that the Metal GPU pipeline correctly:
!   1. Pre-samples fallback sizes for unallocated output descriptors
!   2. Sets correct offsets in the sa_cp loop for null descriptors
!   3. Writes back data from flat GPU buffers to newly-allocated descriptors
!   4. Handles deep copy of Var-to-Var struct assignment in inline functions
program gpu_metal_237
  implicit none

  type :: t
    real, allocatable :: v(:)
  end type

  integer :: n, i
  type(t) :: src(4)
  type(t), allocatable :: dst(:)

  n = 4
  do i = 1, n
    allocate(src(i)%v(1))
    src(i)%v(1) = real(i)
  end do

  allocate(dst(n))

  do concurrent(i = 1:n)
    dst(i) = f(src(i))
  end do

  if (abs(dst(1)%v(1) - 1.0) > 1e-6) error stop
  if (abs(dst(2)%v(1) - 2.0) > 1e-6) error stop
  if (abs(dst(3)%v(1) - 3.0) > 1e-6) error stop
  if (abs(dst(4)%v(1) - 4.0) > 1e-6) error stop
  print *, "PASS"

  do i = 1, n
    deallocate(src(i)%v)
    deallocate(dst(i)%v)
  end do
  deallocate(dst)

contains

  elemental function f(a) result(r)
    type(t), intent(in) :: a
    type(t) :: r
    allocate(r%v(size(a%v)))
    r%v = a%v
  end function

end program
